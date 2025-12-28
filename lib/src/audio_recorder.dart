part of '../fl_recorder.dart';

class AudioDescribe {
  /// 原始数据
  final List<int> byte;

  /// 分贝
  final double decibel;

  AudioDescribe.fromMap(Map map)
      : byte = map['byte'] as List<int>,
        decibel = (map['decibel'] as num).toDouble();
}

typedef FlRecorderCallback = void Function(AudioDescribe audio);

typedef FlRecorderStateCallback = void Function(bool isRecording);

MethodChannel _channel = MethodChannel('fl.recorder');

class FlRecorder {
  factory FlRecorder() => _singleton ??= FlRecorder._();

  FlRecorder._();

  static FlRecorder? _singleton;

  static FlRecorder get instance => FlRecorder();

  /// 录制音频
  final recordRecorder = FlAudioSourceRecorder._(FlAudioSource.record);

  /// 屏幕录制
  final captureRecorder = FlAudioSourceRecorder._(FlAudioSource.capture);

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    return result ?? false;
  }

  /// 设置 ios 音频会话
  Future<bool> setAudioSession({
    required AVAudioSessionCategory category,
    required bool active,
  }) async {
    if (!_isIOS) return false;
    final result = await _channel.invokeMethod<bool>('setAudioSession', {
      'category': category.index,
      'active': active,
    });
    return result ?? false;
  }
}

bool get _supportPlatform => _isAndroid || _isIOS || _isHarmonyOS;

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get _isHarmonyOS => !kIsWeb && defaultTargetPlatform.name == 'ohos';

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
