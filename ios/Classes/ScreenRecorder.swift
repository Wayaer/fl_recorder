//import ReplayKit
//import AVFoundation
//
//class ScreenRecorder {
//
//    private var recorder: RPScreenRecorder
//    private var audioReader: AVAssetReader?
//    private var audioOutput: AVAssetReaderTrackOutput?
//    private var videoURL: URL?
//    private var timer: Timer?
//
//    init() {
//        self.recorder = RPScreenRecorder.shared()
//    }
//
//    // 开始录制
//    func startRecording(completion: @escaping (Error?) -> Void) {
//        if recorder.isAvailable {
//            recorder.startRecording { [weak self] (error) in
//                if let error = error {
//                    completion(error)
//                } else {
//                    print("录制已开始")
//                    self?.startAudioReader()
//                    self?.startTimer()
//                    completion(nil)
//                }
//            }
//        } else {
//            let error = NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recorder is not available"])
//            completion(error)
//        }
//    }
//
//    // 停止录制
//    func stopRecording(completion: @escaping (URL?, Error?) -> Void) {
////        recorder.stopRecording { [weak self] (previewViewController, error) in
////            if let error = error {
////                completion(nil, error)
////            } else {
////                self?.videoURL = previewViewController?.
////                print("录制完成")
////                self?.stopTimer()
////                completion(self?.videoURL, nil)
////            }
////        }
//    }
//
//    // 启动定时器，每秒提取一次音频数据
//    private func startTimer() {
//        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(extractAudioData), userInfo: nil, repeats: true)
//    }
//
//    // 停止定时器
//    private func stopTimer() {
//        timer?.invalidate()
//        timer = nil
//    }
//
//    // 启动音频读取器
//    private func startAudioReader() {
//        guard let videoURL = self.videoURL else { return }
//
//        let asset = AVAsset(url: videoURL)
//        do {
//            audioReader = try AVAssetReader(asset: asset)
//
//            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
//                print("没有找到音频轨道")
//                return
//            }
//
//            audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
//            audioReader?.add(audioOutput!)
//        } catch {
//            print("音频读取器初始化失败: \(error.localizedDescription)")
//        }
//
//        audioReader?.startReading()
//    }
//
//    // 每秒提取一次音频数据
//    @objc private func extractAudioData() {
//        guard let audioReader = audioReader, let audioOutput = audioOutput else {
//            return
//        }
//
//        if audioReader.status == .reading {
//            if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
//                if let audioData = convertSampleBufferToNSData(sampleBuffer) {
//                    print("提取到音频数据: \(audioData.count) 字节")
//                    // 在这里可以处理音频数据，比如保存到文件或发送到网络
//                }
//            }
//        } else if audioReader.status == .completed {
//            print("音频读取完成")
//            stopTimer()
//        }
//    }
//
//    // 将 sampleBuffer 转换为 NSData
//    private func convertSampleBufferToNSData(_ sampleBuffer: CMSampleBuffer) -> NSData? {
//        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
//
//        var length = 0
//        var dataPointer: UnsafeMutablePointer<UInt8>?
//        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffset: nil, totalLength: &length, dataPointerOut: &dataPointer)
//
//        if status != kCMBlockBufferNoErr {
//            return nil
//        }
//
//        return NSData(bytes: dataPointer, length: length)
//    }
//}
