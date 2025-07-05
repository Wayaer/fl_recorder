part of '../fl_recorder.dart';

class AudioDescribe {
  /// 原始数据
  final List<int> byte;

  /// 分贝
  final double decibel;

  AudioDescribe.fromMap(Map map)
      : byte = map['byte'] as List<int>,
        decibel = map['decibel'] as double;
}

/// Audio 来源
enum FlAudioSource {
  /// 麦克风录音
  microphone,

  /// 系统采集音频
  capture
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

typedef FlRecorderCallback = void Function(AudioDescribe audio);

typedef FlRecorderStateCallback = void Function(bool isRecording);

class FlRecorder {
  factory FlRecorder() => _singleton ??= FlRecorder._();

  FlRecorder._();

  static FlRecorder? _singleton;

  final MethodChannel _channel = MethodChannel('fl.recorder');

  final String _eventName = 'fl.recorder.event';

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  FlEventChannel? _flEventChannel;

  /// 录音时间
  Duration _duration = Duration.zero;

  Duration get duration => _duration;
  Timer? _timer;

  /// 开始录音计时
  void _startTimer() {
    _stopTimer();
    final interval = const Duration(milliseconds: 200);
    _timer = Timer.periodic(interval, (timer) {
      _duration += interval;
    });
  }

  /// 停止录音计时
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 初始化 前台任务 和录音工具
  Future<bool> initialize(
      {FlAudioSource source = FlAudioSource.capture}) async {
    if (!_supportPlatform) return false;
    _flEventChannel = await FlChannel().create(_eventName);
    _flEventChannel?.listen(_onData, onError: _onError, onDone: _onDone);
    final result = await _channel.invokeMethod<bool>(
        'initialize', {'source': _isIOS ? 0 : source.index});
    _duration = Duration.zero;
    return _flEventChannel != null && (result ?? false);
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) return false;
    final result =
        await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    return result ?? false;
  }

  /// 开始录音 停止后可重新开启录音
  Future<bool> startRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('startRecording');
    if (result == true) _startTimer();
    return result ?? false;
  }

  /// 停止录音 开启录音后可停止录音
  Future<bool> stopRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('stopRecording');
    if (result == true) _stopTimer();
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
    if (result == true) _stopTimer();
    return result ?? false;
  }

  /// 完全注销录音和前台任务
  Future<bool> dispose({bool disposeEvent = true}) async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('dispose');
    if (result == true) {
      _stopTimer();
      _duration = Duration.zero;
    }
    if (disposeEvent) {
      Future.delayed(const Duration(seconds: 1), () {
        _flEventChannel?.dispose();
      });
    }
    return result ?? false;
  }

  void _onError(dynamic error) {
    _isRecording = false;
  }

  void _onDone() {
    _isRecording = false;
  }

  FlRecorderCallback? _onRecording;
  FlRecorderStateCallback? _onStateChanged;

  /// 数据流监听
  void onChanged(FlRecorderCallback onChanged) {
    _onRecording = onChanged;
  }

  /// 状态变化监听
  void onStateChanged(FlRecorderStateCallback onChanged) {
    _onStateChanged = onChanged;
  }

  void _onData(dynamic data) {
    if (data is Map) {
      _onRecording?.call(AudioDescribe.fromMap(data));
    } else if (data is bool) {
      _isRecording = data;
      _onStateChanged?.call(_isRecording);
    }
  }
}

bool get _supportPlatform => _isAndroid || _isIOS;

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
