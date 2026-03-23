part of '../fl_recorder.dart';

/// Audio 来源
enum FlAudioSource {
  /// 录制
  /// android 默认麦克风
  /// ios 默认麦克风
  /// HarmonyOS 默认麦克风 可根据[SourceTypeForHarmonyOS] 切换
  record,

  /// 采集
  /// android 默认录屏 录制音频流
  /// ios 默认录屏 录制视频流
  /// HarmonyOS 默认录屏 录制视频流
  capture;

  /// 获取对应的录音器
  FlAudioSourceRecorder get recorder => switch (this) {
        record => FlRecorder.instance.recordRecorder,
        capture => FlRecorder.instance.captureRecorder,
      };

  Map<String, dynamic> toMap() => {'source': _isIOS ? 0 : index};
}

/// ios 音频会话
enum AVAudioSessionCategory {
  /// 播放音频
  ambient,

  /// 播放音频 不允许打断
  soloAmbient,

  /// 播放音频
  playback,

  /// 录音
  record,

  /// 同时播放和录音
  playAndRecord,

  /// 同时播放和录音 不允许打断
  multiRoute,
}

enum AudioSourceForAndroid {
  /// 默认音频源,系统自动选择最合适的麦克风（通常就是主麦克风）
  defaultSource(code: 0),

  /// 主麦克风
  /// 直接采集手机底部 / 正面的主麦克风声音，适合录音、语音、普通拾音
  mic(code: 1),

  /// 通话上行声音
  /// 只采集你说话传给对方的声音（通话上行流），一般用于通话录音。
  voiceUplink(code: 2),

  /// 通话下行声音
  /// 只采集对方说话的声音（通话下行流），一般用于通话录音。
  voiceDownlink(code: 3),

  /// 通话双向录音
  /// 采集双方通话声音（上行 + 下行），用于通话录音。
  /// ⚠️ 很多手机厂商做了限制，不一定能用。
  voiceCall(code: 4),

  /// 摄像机麦克风
  /// 使用相机旁边的麦克风，聚焦视频录制，降噪弱、距离远收音更好。
  /// 拍视频时自动用这个。
  camcorder(code: 5),

  /// 语音识别专用麦克风
  /// 为语音识别优化：低延迟、低降噪、高灵敏度。
  /// 做语音转文字、语音助手时推荐用。
  voiceRecognition(code: 6),

  /// 语音通话 / 实时通信
  /// 针对 VoIP、微信语音、视频通话 优化：
  /// 强回声消除、强降噪、低延迟。
  /// 👉 实时语音聊天必选！
  voiceCommunication(code: 7),

  /// 系统内部声音混音
  /// 录制 手机内部播放的声音（音乐、视频、游戏声音）。
  /// ⚠️ 系统级权限，普通 App 用不了。
  remoteSubmix(code: 8),

  /// 无处理原始音频
  /// 不经过系统降噪、回声消除，直接输出麦克风原始声音。
  /// 适合专业录音、音频分析。
  unprocessed(code: 9),

  /// 高性能实时语音
  /// 超低延迟、低处理，用于 实时演唱、乐器录音、专业语音表演。
  /// 要求高的实时音频用它。
  voicePerformance(code: 10);

  const AudioSourceForAndroid({required this.code});

  final int code;

  Map<String, dynamic> toMap() => {'audioSource': code};
}

/// HarmonyOS 音频来源
enum SourceTypeForHarmonyOS {
  /**
   * 麦克风音频源类型
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 8
   */

  /// 麦克风音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  mic(code: 0),

  /**
   * 语音识别音频源类型
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 9
   */

  /// 语音识别音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  voiceRecognition(code: 1),

  /// 播放录制音频源类型（录制系统声音）
  /// @syscap SystemCapability.Multimedia.Audio.PlaybackCapture
  /// @since 10
  /// @deprecated since 12
  /// @useinstead 原生接口中的 OH_AVScreenCapture
  playbackCapture(code: 2),

  /**
   * 语音通话音频源类型
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 8
   */

  /// 语音通话音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  voiceCommunication(code: 7),

  /// 语音消息音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 12
  voiceMessage(code: 10),

  /// 摄像机录制音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 13
  camcorder(code: 13),

  /// 未经过处理的原始音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 14
  unprocessed(code: 14),

  /// 直播音频源类型
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 20
  live(code: 17),
  ;

  const SourceTypeForHarmonyOS({required this.code});

  final int code;

  Map<String, dynamic> toMap() => {'sourceType': code};
}
