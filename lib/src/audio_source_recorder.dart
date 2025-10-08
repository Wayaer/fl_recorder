part of '../fl_recorder.dart';

/// Audio 来源
enum FlAudioSource {
  /// 麦克风录音
  microphone,

  /// 系统采集音频
  capture;

  /// 获取对应的录音器
  FlAudioSourceRecorder get recorder => switch (this) {
        microphone => FlRecorder.instance.microphoneRecorder,
        capture => FlRecorder.instance.captureRecorder,
      };

  Map<String, dynamic> toMap() => {'source': _isIOS ? 0 : index};
}

class FlAudioSourceRecorder {
  final FlAudioSource source;

  FlAudioSourceRecorder._(this.source);

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// 录音时间
  Duration _duration = Duration.zero;

  Duration get duration => _duration;
  Timer? _timer;

  FlEventChannel? _flEventChannel;

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

  String get _eventChannelName => 'fl.recorder.event.${source.name}';

  /// 初始化 前台任务 和录音工具
  Future<bool> initialize() async {
    if (!_supportPlatform) return false;
    _flEventChannel = await FlChannel().create(_eventChannelName);
    _flEventChannel?.listen(_onData, onError: _onError, onDone: _onDone);
    final result = await _channel.invokeMethod<bool>('initialize', source.toMap());
    _duration = Duration.zero;
    return _flEventChannel != null && (result ?? false);
  }

  /// 开始录音 停止后可重新开启录音
  Future<bool> startRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('startRecording', source.toMap());
    if (result == true) _startTimer();
    return result ?? false;
  }

  /// 停止录音 开启录音后可停止录音
  Future<bool> stopRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('stopRecording', source.toMap());
    if (result == true) _stopTimer();
    return result ?? false;
  }

  /// 完全注销录音和前台任务
  Future<bool> dispose({bool disposeEvent = true}) async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('dispose', source.toMap());
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
