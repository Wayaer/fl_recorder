import AVFoundation
import CoreLocation
import fl_channel
import Flutter
import ReplayKit

public class FlRecorderPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate, RPScreenRecorderDelegate {
    var channel: FlutterMethodChannel

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fl.recorder", binaryMessenger: registrar.messenger())
        let plugin = FlRecorderPlugin(channel)
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }

    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    // 麦克风录音
    var microphoneAudioRecorder: MicrophoneAudioRecorder?

    // 录屏
    var screenCaptureAudioRecorder: ScreenCaptureAudioRecorder?

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let args = call.arguments as! [String: Any]
            let source = args["source"] as? Int
            if source == 0 {
                if microphoneAudioRecorder == nil {
                    microphoneAudioRecorder = MicrophoneAudioRecorder()
                    microphoneAudioRecorder?.initialize()
                }
                result(microphoneAudioRecorder != nil)
            } else if source == 1 {
                if screenCaptureAudioRecorder == nil {
                    screenCaptureAudioRecorder = ScreenCaptureAudioRecorder()
                    screenCaptureAudioRecorder?.initialize()
                }
                result(screenCaptureAudioRecorder != nil)
            } else {
                result(false)
            }
        case "startRecording":
            let args = call.arguments as! [String: Any]
            let source = args["source"] as? Int
            if source == 0 {
                if microphoneAudioRecorder != nil {
                    microphoneAudioRecorder?.startRecording(result)
                    return
                }
            } else if source == 1 {
                if screenCaptureAudioRecorder != nil {
                    screenCaptureAudioRecorder?.startRecording(result)
                    return
                }
            } else {
                result(false)
            }
        case "stopRecording":
            let args = call.arguments as! [String: Any]
            let source = args["source"] as? Int
            if source == 0 {
                microphoneAudioRecorder?.stopRecording()
                result(microphoneAudioRecorder != nil)
            } else if source == 1 {
                screenCaptureAudioRecorder?.stopRecording()
                result(screenCaptureAudioRecorder != nil)
            } else {
                result(false)
            }
        case "dispose":
            let args = call.arguments as! [String: Any]
            let source = args["source"] as? Int
            if source == 0 {
                microphoneAudioRecorder?.dispose()
                result(microphoneAudioRecorder != nil)
            } else if source == 1 {
                screenCaptureAudioRecorder?.dispose()
                result(screenCaptureAudioRecorder != nil)
            } else { result(false) }
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
            _ = FlAudioRecorder.setAudioSession(category, active)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        channel.setMethodCallHandler(nil)
    }
}
