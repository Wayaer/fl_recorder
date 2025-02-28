import AVFoundation
import CoreLocation
import fl_channel
import Flutter
import ReplayKit

public class FlRecorderPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate, RPPreviewViewControllerDelegate {
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

    // 音频来源
    var audioSource: Int = 0

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if flEventChannel == nil {
                flEventChannel = FlChannelPlugin.getEventChannel("fl.recorder.event")
            }
            let args = call.arguments as! [String: Any]
            audioSource = args["source"] as! Int
            result(true)
        case "startRecording":

            if audioSource == 0 {
                result(startAudioRecording())
            } else if audioSource == 1 {
                startScreenRecording(result)
            }
        case "stopRecording":
            audioRecorder?.stop()
        case "dispose":
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        channel.setMethodCallHandler(nil)
    }

    func destroy() {
        stopAudioRecording()
        stopScreenRecording()
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
    }

    // 添加时长记录相关的变量
    var recordingStartTime: Date?
    var recordingDuration: TimeInterval = 0.0
    /// ------------------------- AudioRecorder ------------------------ ///
    var audioRecorder: AVAudioRecorder?
    var timer: Timer?
    var segmentDuration: TimeInterval = 1.0 // 数据片段的时间间隔（秒）
    var lastReadOffset: Int = 0 // 上次读取的偏移量
    var recordingUrl: URL?

    // 开始麦克风录音
    func startAudioRecording() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.record, mode: .default, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            UIApplication.shared.beginBackgroundTask(withName: "BackgroundAudio") {
                // 后台任务结束时的清理工作
                print("Background task ended.")
            }

            print("Audio session configured for recording.")
        } catch {
            print("Error configuring audio session: \(error)")
            return false
        }
        // 录音文件的存储路径
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("audioRecording.m4a")
        recordingUrl = fileURL
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            // 启动定时器
            timer = Timer.scheduledTimer(timeInterval: segmentDuration, target: self, selector: #selector(readAudioSegment), userInfo: nil, repeats: true)
            // 开始计时
            recordingStartTime = Date()
            print("Recording started.")
            return true
        } catch {
            print("Error starting recording: \(error)")
        }
        return false
    }

    func stopAudioRecording() {
        audioRecorder?.stop()
        // 停止计时
        if let startTime = recordingStartTime {
            recordingDuration += Date().timeIntervalSince(startTime)
            recordingStartTime = nil
        }
    }

    @objc func readAudioSegment() {
        guard let url = recordingUrl, let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return
        }

        let fileSize = fileHandle.seekToEndOfFile()
        fileHandle.seek(toFileOffset: UInt64(lastReadOffset))

        let newData = fileHandle.readData(ofLength: Int(fileSize) - lastReadOffset)
        fileHandle.closeFile()
        if !newData.isEmpty {
            _ = flEventChannel?.send([
                "byte": newData,
                "timeMillis": recordingDuration,
                "length": newData.count
            ])
            lastReadOffset = Int(fileSize)
        }
    }

    public func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {}
    public func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {}

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully.")
        } else {
            print("Recording failed.")
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {}

    /// ------------------------- ScreenRecorder ------------------------ ///
    var screenRecorder = RPScreenRecorder.shared()

    // 开始录制
    func startScreenRecording(_ result: @escaping FlutterResult) {
        if screenRecorder.isAvailable {
            screenRecorder.startRecording { error in
                if let error = error {
                    print("Error starting recording: \(error)")
                } else {
                    print("System audio recording started.")
                }
                result(error == nil)
            }
        } else {
            result(false)
        }
    }

    // 停止录制
    func stopScreenRecording() {
        screenRecorder.stopRecording { _, _ in
        }
    }

    // 处理预览
    public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        print("Preview finished.")
    }
}
