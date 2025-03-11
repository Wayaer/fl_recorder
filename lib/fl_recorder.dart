import 'dart:math' as math;
import 'dart:async';

import 'package:fl_channel/fl_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioDescribe {
  /// 录音时间
  final int milliseconds;

  /// data 长度
  final int length;

  /// 原始数据
  final List<int> byte;

  AudioDescribe.fromMap(Map map)
      : milliseconds = map['timeMillis'] as int,
        length = map['length'] as int,
        byte = map['byte'] as List<int>;

  /// 计算 db
  double get decibels {
    double sum = 0.0;
    for (int i = 0; i < length; i += 2) {
      // 将每两个字节转换为 16-bit PCM 格式的 short 值
      int sample = (byte[i + 1] << 8) | (byte[i] & 0xFF);

      // 将 sample 转换为 short 类型（16 位有符号整数）
      final sampleValue = sample.toSigned(16);
      sum += (sampleValue * sampleValue).toDouble();
    }

    // 计算均方根值 (RMS)
    double rms = math.sqrt(sum / (length / 2.0)); // 每个样本是 2 个字节
    if (rms == 0.0) return 0.0;
    // 转换为分贝 (dB)
    double dB = 20 * math.log(rms / 32767.0) * math.log10e; // 32767 为 16 位音频的最大值
    if (dB.isNaN) return 0;
    return dB.abs();
  }

  /// pcm 转振幅
  List<double> get toAmplitude {
    const sampleWidth = 2; // 假设为 16 位采样
    const channels = 1; // 假设为单声道
    final frameCount = byte.length ~/ (sampleWidth * channels);
    final pcmFrames = ByteData.view(Uint8List.fromList(byte).buffer);
    final amplitudeFrames = <double>[];
    for (var i = 0; i < frameCount; i++) {
      final value = pcmFrames.getInt16(i * sampleWidth, Endian.little);
      final amplitude = value / 32768.0; // 除以 2^15，归一化到 [-1, 1] 范围
      amplitudeFrames.add(amplitude);
    }
    return amplitudeFrames;
  }
}

/// Audio 来源
enum FlAudioSource {
  /// 麦克风录音
  microphone,

  /// 系统采集音频
  capture
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

  /// 初始化 前台任务 和录音工具
  Future<bool> initialize({FlAudioSource source = FlAudioSource.capture}) async {
    if (!_supportPlatform) return false;
    _flEventChannel = await FlChannel().create(_eventName);
    _flEventChannel?.listen(_onData, onError: _onError, onDone: _onDone);
    final result = await _channel.invokeMethod<bool>('initialize', {'source': _isIOS ? 0 : source.index});
    return _flEventChannel != null && (result ?? false);
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    return result ?? false;
  }

  /// 开始录音 停止后可重新开启录音
  Future<bool> startRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('startRecording');
    return result ?? false;
  }

  /// 停止录音 开启录音后可停止录音
  Future<bool> stopRecording() async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('stopRecording');
    return result ?? false;
  }

  /// 完全注销录音和前台任务
  Future<bool> dispose({bool disposeEvent = true}) async {
    if (!_supportPlatform) return false;
    final result = await _channel.invokeMethod<bool>('dispose');
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

  void _onData(data) {
    if (data is Map) {
      _onRecording?.call(AudioDescribe.fromMap(data));
    } else if (data is bool) {
      _isRecording = data;
      _onStateChanged?.call(_isRecording);
    }
  }
}

bool get _supportPlatform => _isAndroid || _isIOS;

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
