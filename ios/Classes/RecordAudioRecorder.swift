import AVFAudio
import AVFoundation
import fl_channel
import Flutter

class RecordAudioRecorder: FlAudioRecorder, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    var timer: Timer?
    var segmentDuration: TimeInterval = 0.1 // 数据片段的时间间隔（秒）
    var lastReadOffset: Int = 0 // 上次读取的偏移量
    var recordingUrl: URL?

    init() {
        super.init("record")
    }

    override func startRecording(_ result: @escaping FlutterResult) {
        if isRecording {
            result(false)
            return
        }
        startAudioRecording(result)
    }

    override func stopRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        _ = FlAudioRecorder.setAudioSession(.playback, false)
        super.stopRecording()
        /// 录音结束录制
        timer?.invalidate()
        timer = nil
        lastReadOffset = 0
        recordingUrl = nil
        isRecording = false
    }

    // 开始麦克风录音
    func startAudioRecording(_ result: @escaping FlutterResult) {
        FlAudioRecorder.audioSession.requestRecordPermission { granted in
            if granted {
                let state = FlAudioRecorder.setAudioSession(.record, true)
                if state {
                    self.beginBackgroundTask("RecordAudioRecorder")
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
                    self.isRecording = true
                    _ = self.sendData(true)
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
        _ = sendData([
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
        _ = sendData(true)
    }

    public func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        _ = sendData(false)
    }

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        _ = sendData(false)
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        _ = sendData(false)
        stopRecording()
    }
}
