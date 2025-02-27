import 'dart:typed_data';

import 'package:fl_extended/fl_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fl_recorder/fl_recorder.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
      navigatorKey: FlExtended().navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(title: const Text('FlRecorder Plugin example')),
          body: const Padding(
            padding: EdgeInsets.all(12),
            child: SingleChildScrollView(child: _App()),
          ))));
}

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final recording = FlRecorder();
  List<int> byte = [];
  List<double> amplitude = [];

  String text = '';

  @override
  void initState() {
    super.initState();
    addPostFrameCallback((_) {
      recording.onChanged((AudioDescribe audio) {
        byte.addAll(audio.byte);
        amplitude.addAll(audio.toAmplitude);
        text = ("isRecording:${recording.isRecording}\n"
            "milliseconds:${Duration(milliseconds: audio.milliseconds)}\n"
            "byte:${byte.length}\n"
            "amplitude:${amplitude.length}");
        debugPrint(text);
        if (mounted) setState(() {});
      });
      recording.onStateChanged((bool isRecording) {
        debugPrint("isRecording:$isRecording");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          height: 140,
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.black12.withValues(alpha: 0.1)),
          child: Text(text)),
      Wrap(runSpacing: 10, spacing: 10, children: [
        if (isAndroid)
          ElevatedText(
              text: 'requestIgnoreBatteryOptimizations',
              onPressed: () async {
                final result =
                    await recording.requestIgnoreBatteryOptimizations();
                text = "requestIgnoreBatteryOptimizations : $result";
                setState(() {});
              }),
        ElevatedText(
            text: 'initialize(FlAudioSource.capture)',
            onPressed: () async {
              final result =
                  await recording.initialize(source: FlAudioSource.capture);
              text = "initialize(FlAudioSource.capture) : $result";
              setState(() {});
            }),
        ElevatedText(
            text: 'initialize(FlAudioSource.microphone)',
            onPressed: () async {
              final result =
                  await recording.initialize(source: FlAudioSource.microphone);
              text = "initialize(FlAudioSource.microphone) : $result";
              setState(() {});
            }),
        ElevatedText(
            text: 'startRecording',
            onPressed: () async {
              final result = await recording.startRecording();
              text = "startRecording : $result";
              debugPrint(text);
              setState(() {});
            }),
        ElevatedText(
            text: 'stopRecording',
            onPressed: () async {
              final result = await recording.stopRecording();
              text = "stopRecording : $result";
              debugPrint(text);
              setState(() {});
            }),
        ElevatedText(
            text: 'dispose',
            onPressed: () async {
              final result = await recording.dispose();
              text = "dispose : $result";
              setState(() {});
            }),
        ElevatedText(text: '播放录音数据', onPressed: playRecordData),
      ])
    ]);
  }

  final player = FlutterSoundPlayer();

  void playRecordData() async {
    if (byte.isEmpty) {
      showToast('请先录音数据');
      return;
    }
    showToast('开始播放录音');
    await player.openPlayer();
    player.startPlayer(
        codec: Codec.pcm16,
        fromDataBuffer: Uint8List.fromList(byte),
        whenFinished: () {
          showToast('播放完毕');
          player.stopPlayer();
          player.dispositionStream();
        });
  }
}

class Partition extends StatelessWidget {
  const Partition(this.title, {super.key, this.onTap});

  final String title;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) => Universal(
      onTap: onTap,
      width: double.infinity,
      color: Colors.grey.withValues(alpha: 0.2),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: BText(title, fontWeight: FontWeight.bold));
}

class ElevatedText extends StatelessWidget {
  const ElevatedText({super.key, required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      ElevatedButton(onPressed: onPressed, child: Text(text));
}
