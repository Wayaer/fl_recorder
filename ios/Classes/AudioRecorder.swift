import AVFoundation
import fl_channel
import Flutter

class FlAudioRecorder: NSObject {
    private var flEventChannel: FlEventChannel?

    public var isRecording: Bool = false

    public var sourceEvent: String

    init(_ sourceEvent: String) {
        self.sourceEvent = sourceEvent
    }

    public func getEventChannel() -> FlEventChannel? {
        if flEventChannel == nil {
            flEventChannel = FlChannelPlugin.getEventChannel("fl.recorder.event.\(sourceEvent)")
        }
        return flEventChannel
    }

    public func sendData(_ args: Any) -> Bool {
        return flEventChannel?.send(args) == true
    }

    // 初始化
    public func initialize() {
        _ = getEventChannel()
    }

    // 开始录制
    public func startRecording(_ result: @escaping FlutterResult) {}

    // 停止录制
    public func stopRecording() { endBackgroundTask() }

    // 销毁
    public func dispose() {
        stopRecording()
        isRecording = false
    }

    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    func beginBackgroundTask(_ taskName: String) {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // 后台任务结束时的清理工作
            print("Background task (\(taskName) ended.")
        }
    }

    func endBackgroundTask() {
        if backgroundTaskIdentifier != nil {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier!)
            backgroundTaskIdentifier = nil
        }
    }

    static let audioSession = AVAudioSession.sharedInstance()
    static func setAudioSession(_ category: AVAudioSession.Category, _ active: Bool) -> Bool {
        do {
            try audioSession.setCategory(category, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(active, options: active ? .notifyOthersOnDeactivation : [])
            return true
        } catch {
            print("FlAudioRecorder setAudioSession: \(error)")
        }
        return false
    }
}
