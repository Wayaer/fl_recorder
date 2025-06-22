part of '../fl_recorder.dart';

extension ExtensionAudioDescribeToAmplitudes on AudioDescribe {
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

  /// pcm 转振幅并进行缩放
  List<double> scaledAmplitude({double scaleFactor = 1.0}) {
    const sampleWidth = 2; // 假设为 16 位采样
    const channels = 1; // 假设为单声道
    final frameCount = byte.length ~/ (sampleWidth * channels);
    final pcmFrames = ByteData.view(Uint8List.fromList(byte).buffer);
    final amplitudeFrames = <double>[];

    // 原始范围 [-1, 1] 的中心点
    const originalCenter = 0.0;
    // 目标范围 [2, 200] 的中心点
    const targetCenter = (2.0 + 200.0) / 2.0;
    // 目标范围的半宽
    const targetHalfWidth = (200.0 - 2.0) / 2.0;

    for (var i = 0; i < frameCount; i++) {
      // 从PCM数据中获取原始振幅并归一化
      final value = pcmFrames.getInt16(i * sampleWidth, Endian.little);
      final normalizedAmplitude = value / 32768.0; // 归一化到 [-1, 1]

      // 应用缩放因子（以中心点为基准进行缩放）
      double scaledValue;
      if (scaleFactor == 1.0) {
        // 无缩放，直接映射
        scaledValue = normalizedAmplitude;
      } else {
        // 计算相对于中心点的偏移
        final offset = normalizedAmplitude - originalCenter;
        // 应用缩放因子
        final scaledOffset = offset * scaleFactor;
        // 重新定位到中心点
        scaledValue = originalCenter + scaledOffset;
      }

      // 限制在原始范围 [-1, 1] 内，防止溢出
      final clampedValue = scaledValue.clamp(-1.0, 1.0);

      // 线性映射到目标范围 [2, 200]
      final targetValue = targetCenter + clampedValue * targetHalfWidth;

      amplitudeFrames.add(targetValue);
    }

    return amplitudeFrames;
  }
}

class FlAudioAmplitudeWave extends StatelessWidget {
  const FlAudioAmplitudeWave({super.key, required this.data, this.color = Colors.red, this.height = 200});

  final List<double> data;

  final Color color;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        itemCount: data.length,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        reverse: true,
        itemBuilder: (_, int index) {
          final item = data[index];
          return Container(
              width: 2,
              margin: EdgeInsets.symmetric(horizontal: 1),
              height: double.infinity,
              alignment: Alignment.center,
              child: Container(width: double.infinity, height: item, color: color));
        },
      ),
    );
  }
}
