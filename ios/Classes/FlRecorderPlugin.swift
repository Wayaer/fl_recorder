import AVFoundation
import CoreLocation
import fl_channel
import Flutter
import ReplayKit

public class FlRecorderPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate, RPScreenRecorderDelegate {
    var channel: FlutterMethodChannel
    var flEventChannel: FlEventChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fl.recorder", binaryMessenger: registrar.messenger())
        let plugin = FlRecorderPlugin(channel)
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }

    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if flEventChannel == nil {
                flEventChannel = FlChannelPlugin.getEventChannel("fl.recorder.event")
            }
            let args = call.arguments as! [String: Any]
            audioSource = args["source"] as? Int
            result(true)
        case "startRecording":
            startRecording(result)
        case "stopRecording":
            stopRecording()
            result(true)
        case "setAudioSession":
            let args = call.arguments as! [String: Any]
            let categoryIndex = args["category"] as! Int
            let active = args["active"] as! Bool
            var category: AVAudioSession.Category = .playback
            switch categoryIndex {
            case 0:
                category = .ambient
            case 1:
                category = .soloAmbient
            case 2:
                category = .playback
            case 3:
                category = .record
            case 4:
                category = .playAndRecord
            case 5:
                category = .multiRoute
            default:
                category = .playback
            }
            _ = setAudioSession(category, active)
            result(true)
        case "dispose":
            destroy()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        channel.setMethodCallHandler(nil)
    }

    // 音频来源
    var audioSource: Int?

    var isRecording: Bool = false

    func startRecording(_ result: @escaping FlutterResult) {
        if isRecording || audioSource == nil {
            result(false)
            return
        }
        isRecording = true
        _ = flEventChannel?.send(true)
        if audioSource == 0 {
            startAudioRecording(result)
        } else if audioSource == 1 {
            startScreenRecording(result)
        }
    }

    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    func setAudioSession(_ category: AVAudioSession.Category, _ active: Bool) -> Bool {
        do {
            try audioSession.setCategory(category, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(active, options: active ? .notifyOthersOnDeactivation : [])
            return true
        } catch {
            print("FlRecorder setAudioSession: \(error)")
        }
        return false
    }

    func stopRecording() {
        if audioSource == 0 {
            audioRecorder?.stop()
            audioRecorder?.deleteRecording()
            _ = setAudioSession(.playback, false)
        } else if audioSource == 1 {
            /// 录屏结束录制
            if screenRecorder.isRecording {
                screenRecorder.stopCapture()
                screenRecorder.stopRecording()
            }
        }
        if backgroundTaskIdentifier != nil {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier!)
            backgroundTaskIdentifier = nil
        }

        /// 录音结束录制
        timer?.invalidate()
        timer = nil
        lastReadOffset = 0
        recordingUrl = nil
        isRecording = false
    }

    func destroy() {
        stopRecording()
        audioSource = nil
        isRecording = false
        flEventChannel = nil
    }

    /// ------------------------- AudioRecorder ------------------------ ///
    var audioRecorder: AVAudioRecorder?
    var timer: Timer?
    var segmentDuration: TimeInterval = 0.1 // 数据片段的时间间隔（秒）
    var lastReadOffset: Int = 0 // 上次读取的偏移量
    var recordingUrl: URL?
    let audioSession = AVAudioSession.sharedInstance()
    // 开始麦克风录音
    func startAudioRecording(_ result: @escaping FlutterResult) {
        audioSession.requestRecordPermission { granted in
            if granted {
                let state = self.setAudioSession(.record, true)
                if state {
                    self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "BackgroundAudio") {
                        // 后台任务结束时的清理工作
                        print("Background task ended.")
                    }
                } else {
                    result(false)
                    return
                }
                // 录音文件的存储路径
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.pcm")
                self.recordingUrl = fileURL
                let settings: [String: Any] = [
                    AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),
                    // 设置格式为 PCM
                    AVSampleRateKey: NSNumber(value: 16000.0), // 设置采样率为 16kHz
                    AVNumberOfChannelsKey: NSNumber(value: 1), // 设置为单声道
                    AVLinearPCMBitDepthKey: NSNumber(value: 16), // 设置每个样本的位深度为 16
                    AVLinearPCMIsBigEndianKey: NSNumber(value: false), // 设置为小端序（通常是小端）
                    AVLinearPCMIsFloatKey: NSNumber(value: false) // 设置为整数 PCM
                ]

                do {
                    self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                    self.audioRecorder?.delegate = self
                    // 启动定时器
                    self.timer = Timer.scheduledTimer(timeInterval: self.segmentDuration, target: self, selector: #selector(self.readAudioSegment), userInfo: nil, repeats: true)
                    self.audioRecorder?.isMeteringEnabled = true // 启用音频计量
                    self.audioRecorder?.prepareToRecord()
                    self.audioRecorder?.record()
                    result(true)
                    return
                } catch {
                    self.stopRecording()
                    print("Error starting recording: \(error)")
                }
                result(false)
            } else {
                result(false)
            }
        }
    }

    @objc func readAudioSegment() {
        guard let url = recordingUrl, let fileHandle = try? FileHandle(forReadingFrom: url) else {
            print("FlRecorder Error opening file for reading.")
            return
        }

        let fileSize = fileHandle.seekToEndOfFile()
        fileHandle.seek(toFileOffset: UInt64(lastReadOffset))
        let newData = fileHandle.readData(ofLength: Int(fileSize) - lastReadOffset)
        _ = flEventChannel?.send([
            "byte": newData,
            "decibel": getNormalizedDecibel()
        ])
        lastReadOffset = Int(fileSize)
        fileHandle.closeFile()
    }

    // 获取当前音频的平均分贝值（归一化为 0.0-1.0 范围）
    func getNormalizedDecibel() -> Float {
        guard let recorder = audioRecorder, isRecording else { return 0.0 }

        // 获取平均功率 (-100.0 到 0.0)
        recorder.updateMeters()
        var averagePower = recorder.averagePower(forChannel: 0)
        if averagePower < -100.0 { // 忽略极低的噪声
            averagePower = 0.0
        } else if averagePower > 0 {
            averagePower = 1
        }
        return (averagePower + 100.0) / 100.0 // 将 -100dB 到 0dB 映射到 0.0 到 1.0
    }

    public func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        _ = flEventChannel?.send(true)
    }

    public func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        _ = flEventChannel?.send(false)
    }

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        _ = flEventChannel?.send(false)
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        _ = flEventChannel?.send(false)
        stopRecording()
    }

    /// ------------------------- ScreenRecorder ------------------------ ///
    var screenRecorder = RPScreenRecorder.shared()

    // 开始录制
    func startScreenRecording(_ result: @escaping FlutterResult) {
        if screenRecorder.isAvailable {
            screenRecorder.delegate = self
            screenRecorder.isMicrophoneEnabled = false

            screenRecorder.startCapture(handler: { [self] _, _, error in
                if error != nil {
                    isRecording = false
                    _ = flEventChannel?.send(false)
                } else {
//                     switch bufferType {
//                     case .audioApp:
                    // //                         convertSampleBufferToNSData(buffer)
//                     case .video:
//                         break
//                     case .audioMic:
//                         break
//                     @unknown default:
//                         break
//                     }
                }
            })
        } else {
            result(false)
        }
    }

    public func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        // print("=======screenRecorderDidChangeAvailability")
//        _ = flEventChannel?.send(true)
    }

    public func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: (any Error)?) {
        _ = flEventChannel?.send(false)
    }

    public func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: any Error, previewViewController: RPPreviewViewController?) {
        _ = flEventChannel?.send(false)
        stopRecording()
    }

    // 将 sampleBuffer 转换为 NSData
//     func convertSampleBufferToNSData(_ sampleBuffer: CMSampleBuffer) -> NSData? {
//         guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
//
//         var length = 0
//         var dataPointer: UnsafeMutablePointer<UInt8>?
//         let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffset: nil, totalLength: &length, dataPointerOut: &dataPointer)
//
//         if status != kCMBlockBufferNoErr {
//             return nil
//         }
//
//         return NSData(bytes: dataPointer, length: length)
//     }
}
