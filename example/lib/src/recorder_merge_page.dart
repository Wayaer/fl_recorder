import 'dart:typed_data';

import 'package:example/main.dart';
import 'package:fl_extended/fl_extended.dart';
import 'package:fl_recorder/fl_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class RecorderMergePage extends StatefulWidget {
  const RecorderMergePage({super.key});

  @override
  State<RecorderMergePage> createState() => _RecorderMergePageState();
}

class _RecorderMergePageState extends State<RecorderMergePage> {
  FlAudioSourceRecorder captureRecorder = FlAudioSource.capture.recorder;
  FlAudioSourceRecorder microphoneRecorder = FlAudioSource.microphone.recorder;
  List<int> captureByte = [];
  List<int> microphoneByte = [];
  List<double> captureDecibels = [];
  List<double> microphoneDecibels = [];
  String captureText = '';
  String microphoneText = '';

  @override
  void initState() {
    super.initState();
    addPostFrameCallback((_) {
      init();
      init();
    });
  }

  void init() {
    captureRecorder.onChanged((AudioDescribe audio) {
      captureByte.addAll(audio.byte);
      captureDecibels.add(audio.decibel);
      captureText = ("isRecording:${captureRecorder.isRecording}\n"
          "byte:${captureByte.length}\n"
          "length:${audio.byte.length}\n"
          "duration:${captureRecorder.duration}\n"
          "decibel:${audio.decibel}");
      if (mounted) setState(() {});
    });
    captureRecorder.onStateChanged((bool isRecording) {
      debugPrint("isRecording:$isRecording");
    });
    microphoneRecorder.onChanged((AudioDescribe audio) {
      microphoneByte.addAll(audio.byte);
      microphoneDecibels.add(audio.decibel);
      microphoneText = ("isRecording:${microphoneRecorder.isRecording}\n"
          "byte:${microphoneByte.length}\n"
          "length:${audio.byte.length}\n"
          "duration:${microphoneRecorder.duration}\n"
          "decibel:${audio.decibel}");
      if (mounted) setState(() {});
    });
    microphoneRecorder.onStateChanged((bool isRecording) {
      debugPrint("isRecording:$isRecording");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('麦克风和音频采集')),
      body: Universal(isScroll: true, children: [
        Text('音频采集'),
        Card(
            child: Column(children: [
          FlAudioDecibelsWave(minDecibel: 0.65, scaleFactor: 4, data: captureDecibels.reversed.toList()),
          Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(captureText))
        ])),
        Text('麦克风'),
        Card(
            child: Column(children: [
          FlAudioDecibelsWave(minDecibel: 0.65, scaleFactor: 4, data: microphoneDecibels.reversed.toList()),
          Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(microphoneText))
        ])),
        ElevatedText(
            text: 'initialize',
            onPressed: () async {
              final captureResult = await captureRecorder.initialize();
              captureText = "initialize : $captureResult";
              final microphoneResult = await microphoneRecorder.initialize();
              microphoneText = "initialize : $microphoneResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'startRecording',
            onPressed: () async {
              final captureResult = await captureRecorder.startRecording();
              captureText = "startRecording : $captureResult";
              final microphoneResult = await microphoneRecorder.startRecording();
              microphoneText = "startRecording : $microphoneResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'stopRecording',
            onPressed: () async {
              final captureResult = await captureRecorder.stopRecording();
              captureText = "stopRecording : $captureResult";
              final microphoneResult = await microphoneRecorder.stopRecording();
              microphoneText = "stopRecording : $microphoneResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'dispose',
            onPressed: () async {
              final captureResult = await captureRecorder.dispose();
              captureText = "dispose : $captureResult";
              final microphoneResult = await microphoneRecorder.dispose();
              microphoneText = "dispose : $microphoneResult";
              setState(() {});
            }),
        ElevatedText(text: '播放录音数据', onPressed: playRecordData)
      ]),
    );
  }

  final capturePlayer = FlutterSoundPlayer();
  final microphonePlayer = FlutterSoundPlayer();

  void playRecordData() async {
    if (captureDecibels.isEmpty && microphoneDecibels.isEmpty) {
      showToast('请先录音数据');
      return;
    }
    showToast('开始播放录音');
    await capturePlayer.openPlayer();
    capturePlayer.startPlayer(
        codec: Codec.pcm16,
        fromDataBuffer: Uint8List.fromList(captureByte),
        whenFinished: () async {
          await capturePlayer.stopPlayer();
          capturePlayer.closePlayer();
        });
    await microphonePlayer.openPlayer();
    microphonePlayer.startPlayer(
        codec: Codec.pcm16,
        fromDataBuffer: Uint8List.fromList(microphoneByte),
        whenFinished: () async {
          await microphonePlayer.stopPlayer();
          microphonePlayer.closePlayer();
        });
  }

  @override
  void dispose() {
    super.dispose();
    captureRecorder.dispose();
    microphoneRecorder.dispose();
  }
}
