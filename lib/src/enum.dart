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

/// HarmonyOS 音频来源
enum SourceTypeForHarmonyOS {
  /**
   * Mic source type.
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 8
   */

  /// Mic source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  mic(code: 0),
  /**
   * Voice recognition source type.
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 9
   */

  /// Voice recognition source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  voiceRecognition(code: 1),

  /// Playback capture source type.
  /// @syscap SystemCapability.Multimedia.Audio.PlaybackCapture
  /// @since 10
  /// @deprecated since 12
  /// @useinstead OH_AVScreenCapture in native interface.
  playbackCapture(code: 2),
  /**
   * Voice communication source type.
   * @syscap SystemCapability.Multimedia.Audio.Core
   * @since 8
   */

  /// Voice communication source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @crossplatform
  /// @since 12
  voiceCommunication(code: 7),

  /// Voice message source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 12
  voiceMessage(code: 10),

  /// Camcorder source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 13
  camcorder(code: 13),

  /// Unprocessed source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 14
  unprocessed(code: 14),

  /// Live broadcast source type.
  /// @syscap SystemCapability.Multimedia.Audio.Core
  /// @since 20
  live(code: 17),
  ;

  const SourceTypeForHarmonyOS({required this.code});

  final int code;

  Map<String, dynamic> toMap() => {'sourceType': code};
}
