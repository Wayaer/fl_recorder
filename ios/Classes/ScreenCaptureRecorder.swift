import AVFoundation
import fl_channel
import Flutter
import ReplayKit

class ScreenCaptureRecorder: FlAudioRecorder, RPScreenRecorderDelegate {
    var screenRecorder = RPScreenRecorder.shared()

    init() {
        super.init("capture")
    }

    override func startRecording(_ result: @escaping FlutterResult) {
        if isRecording {
            result(false)
            return
        }
        isRecording = true
        _ = sendData(true)
        startScreenRecording(result)
    }

    override func stopRecording() {
        /// 录屏结束录制
        if screenRecorder.isRecording {
            screenRecorder.stopCapture()
            screenRecorder.stopRecording()
        }
        super.stopRecording()
    }

    // 开始录制
    func startScreenRecording(_ result: @escaping FlutterResult) {
        if screenRecorder.isAvailable {
            screenRecorder.delegate = self
            screenRecorder.isMicrophoneEnabled = false
            screenRecorder.startCapture(handler: { [self] _, _, error in
                if error != nil {
                    isRecording = false
                    _ = sendData(false)
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
        _ = sendData(false)
    }

    public func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: any Error, previewViewController: RPPreviewViewController?) {
        _ = sendData(false)
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
