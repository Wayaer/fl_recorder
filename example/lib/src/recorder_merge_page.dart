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
  FlAudioSourceRecorder recordRecorder = FlAudioSource.record.recorder;
  List<int> captureByte = [];
  List<int> recordByte = [];
  List<double> captureDecibels = [];
  List<double> recordDecibels = [];
  String captureText = '';
  String recordText = '';

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
    recordRecorder.onChanged((AudioDescribe audio) {
      recordByte.addAll(audio.byte);
      recordDecibels.add(audio.decibel);
      recordText = ("isRecording:${recordRecorder.isRecording}\n"
          "byte:${recordByte.length}\n"
          "length:${audio.byte.length}\n"
          "duration:${recordRecorder.duration}\n"
          "decibel:${audio.decibel}");
      if (mounted) setState(() {});
    });
    recordRecorder.onStateChanged((bool isRecording) {
      debugPrint("isRecording:$isRecording");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('录制和采集')),
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
          FlAudioDecibelsWave(minDecibel: 0.65, scaleFactor: 4, data: recordDecibels.reversed.toList()),
          Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Text(recordText))
        ])),
        ElevatedText(
            text: 'initialize',
            onPressed: () async {
              final captureResult = await captureRecorder.initialize();
              captureText = "initialize : $captureResult";
              final recordResult = await recordRecorder.initialize();
              recordText = "initialize : $recordResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'startRecording',
            onPressed: () async {
              final captureResult = await captureRecorder.startRecording();
              captureText = "startRecording : $captureResult";
              final recordResult = await recordRecorder.startRecording();
              recordText = "startRecording : $recordResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'stopRecording',
            onPressed: () async {
              final captureResult = await captureRecorder.stopRecording();
              captureText = "stopRecording : $captureResult";
              final recordResult = await recordRecorder.stopRecording();
              recordText = "stopRecording : $recordResult";
              setState(() {});
            }),
        ElevatedText(
            text: 'dispose',
            onPressed: () async {
              final captureResult = await captureRecorder.dispose();
              captureText = "dispose : $captureResult";
              final recordResult = await recordRecorder.dispose();
              recordText = "dispose : $recordResult";
              setState(() {});
            }),
        ElevatedText(text: '播放录音数据', onPressed: playRecordData)
      ]),
    );
  }

  final capturePlayer = FlutterSoundPlayer();
  final recordPlayer = FlutterSoundPlayer();

  void playRecordData() async {
    if (captureDecibels.isEmpty && recordDecibels.isEmpty) {
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
    await recordPlayer.openPlayer();
    recordPlayer.startPlayer(
        codec: Codec.pcm16,
        fromDataBuffer: Uint8List.fromList(recordByte),
        whenFinished: () async {
          await recordPlayer.stopPlayer();
          recordPlayer.closePlayer();
        });
  }

  @override
  void dispose() {
    super.dispose();
    captureRecorder.dispose();
    recordRecorder.dispose();
  }
}
