import 'dart:typed_data';

import 'package:fl_extended/fl_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fl_recorder/fl_recorder.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: FlExtended().navigatorKey,
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark(),
        theme: ThemeData.light(),
        home: Scaffold(
            appBar: AppBar(title: const Text('FlRecorder Plugin example')),
            body: const Padding(
              padding: EdgeInsets.all(12),
              child: SingleChildScrollView(child: HomePage()),
            )));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final recording = FlRecorder();
  List<int> byte = [];
  List<double> decibels = [];

  String text = '';

  @override
  void initState() {
    super.initState();
    addPostFrameCallback((_) {
      recording.onChanged((AudioDescribe audio) {
        byte.addAll(audio.byte);
        decibels.add(audio.decibel);
        text = ("isRecording:${recording.isRecording}\n"
            "byte:${byte.length}\n"
            "length:${audio.byte.length}\n"
            "duration:${recording.duration}\n"
            "decibel:${audio.decibel}");
        if (mounted) setState(() {});
      });
      recording.onStateChanged((bool isRecording) {
        debugPrint("isRecording:$isRecording");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Universal(isScroll: true, children: [
      FlAudioDecibelsWave(minDecibel: 0.65, scaleFactor: 4, data: decibels.reversed.toList()),
      12.heightBox,
      Card(
          child: Container(
              height: 140,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(text))),
      Wrap(runSpacing: 10, spacing: 10, children: [
        if (isAndroid)
          ElevatedText(
              text: 'requestIgnoreBatteryOptimizations',
              onPressed: () async {
                final result = await recording.requestIgnoreBatteryOptimizations();
                text = "requestIgnoreBatteryOptimizations : $result";
                setState(() {});
              }),
        ElevatedText(
            text: 'initialize(FlAudioSource.capture)',
            onPressed: () async {
              final result = await recording.initialize(source: FlAudioSource.capture);
              text = "initialize(FlAudioSource.capture) : $result";
              setState(() {});
            }),
        ElevatedText(
            text: 'initialize(FlAudioSource.microphone)',
            onPressed: () async {
              final result = await recording.initialize(source: FlAudioSource.microphone);
              text = "initialize(FlAudioSource.microphone) : $result";
              setState(() {});
            }),
        ElevatedText(
            text: 'startRecording',
            onPressed: () async {
              recorder.openRecorder();
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
  final recorder = FlutterSoundRecorder();

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
        whenFinished: () async {
          showToast('播放完毕');
          await player.stopPlayer();
          player.closePlayer();
        });
  }
}

class ElevatedText extends StatelessWidget {
  const ElevatedText({super.key, required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(onPressed: onPressed, child: Text(text));
}
