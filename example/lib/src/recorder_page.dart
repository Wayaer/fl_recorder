import 'dart:typed_data';

import 'package:example/main.dart';
import 'package:fl_extended/fl_extended.dart';
import 'package:fl_recorder/fl_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class AudioSourceRecorderPage extends StatefulWidget {
  const AudioSourceRecorderPage({super.key, required this.source});

  final FlAudioSource source;

  @override
  State<AudioSourceRecorderPage> createState() => _AudioSourceRecorderPageState();
}

class _AudioSourceRecorderPageState extends State<AudioSourceRecorderPage> {
  late FlAudioSourceRecorder recorder;
  List<int> byte = [];
  List<double> decibels = [];

  String text = '';

  @override
  void initState() {
    super.initState();
    recorder = widget.source.recorder;
    addPostFrameCallback((_) {
      recorder.onChanged((AudioDescribe audio) {
        byte.addAll(audio.byte);
        decibels.add(audio.decibel);
        text = ("isRecording:${recorder.isRecording}\n"
            "byte:${byte.length}\n"
            "length:${audio.byte.length}\n"
            "duration:${recorder.duration}\n"
            "decibel:${audio.decibel}");
        if (mounted) setState(() {});
      });
      recorder.onStateChanged((bool isRecording) {
        debugPrint("isRecording:$isRecording");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.source}')),
      body: Universal(isScroll: true, children: [
        FlAudioDecibelsWave(minDecibel: 0.65, scaleFactor: 4, data: decibels.reversed.toList()),
        12.heightBox,
        Card(
            child: Container(
                height: 140,
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(10),
                child: Text(text))),
        ElevatedText(
            text: 'initialize',
            onPressed: () async {
              final result = await recorder.initialize();
              text = "initialize : $result";
              setState(() {});
            }),
        ElevatedText(
            text: 'startRecording',
            onPressed: () async {
              final result = await recorder.startRecording();
              text = "startRecording : $result";
              debugPrint(text);
              setState(() {});
            }),
        ElevatedText(
            text: 'stopRecording',
            onPressed: () async {
              final result = await recorder.stopRecording();
              text = "stopRecording : $result";
              debugPrint(text);
              setState(() {});
            }),
        ElevatedText(
            text: 'dispose',
            onPressed: () async {
              final result = await recorder.dispose();
              text = "dispose : $result";
              setState(() {});
            }),
        ElevatedText(text: '播放录音数据', onPressed: playRecordData)
      ]),
    );
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
        whenFinished: () async {
          showToast('播放完毕');
          await player.stopPlayer();
          player.closePlayer();
        });
  }

  @override
  void dispose() {
    super.dispose();
    recorder.dispose();
  }
}
