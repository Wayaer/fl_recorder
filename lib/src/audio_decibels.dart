part of '../fl_recorder.dart';

/// 分贝波形
class FlAudioDecibelsWave extends StatelessWidget {
  const FlAudioDecibelsWave(
      {super.key,
      required this.data,
      this.color = Colors.red,
      this.minHeight = 2,
      this.minDecibel = 0.45,
      this.scaleFactor = 3,
      this.maxHeight = 100})
      : assert(minDecibel > 0 && minDecibel < 1);

  /// 分贝数据
  final List<double> data;

  final Color color;

  /// 最大高度
  final double maxHeight;

  /// 最小高度
  final double minHeight;

  /// 最小分贝值 低于 0.45 会被忽略
  final double minDecibel;

  /// 缩放因子
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      child: ListView.builder(
        itemCount: data.length,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        reverse: true,
        itemBuilder: (_, int index) {
          double item = data[index] - minDecibel;
          if (item < 0) item = 0;
          double height = item * maxHeight * scaleFactor;
          if (height < minHeight) height = minHeight;
          if (item > maxHeight) height = maxHeight;
          return Container(
              width: 2,
              margin: EdgeInsets.symmetric(horizontal: 1),
              height: double.infinity,
              alignment: Alignment.center,
              child: Container(
                  width: double.infinity, height: height, color: color));
        },
      ),
    );
  }
}
