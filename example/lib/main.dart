import 'package:example/src/recorder_merge_page.dart';
import 'package:example/src/recorder_page.dart';
import 'package:fl_extended/fl_extended.dart';
import 'package:fl_recorder/fl_recorder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
        scaffoldMessengerKey: FlExtended().scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark(),
        theme: ThemeData.light(),
        home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('FlRecorder Plugin example')),
        body: Universal(width: double.infinity, children: [
          if (isAndroid)
            ElevatedText(
                text: 'requestIgnoreBatteryOptimizations',
                onPressed: () async {
                  final result = await FlRecorder.instance.requestIgnoreBatteryOptimizations();
                  showSnackBar(SnackBar(content: Text("requestIgnoreBatteryOptimizations : $result")));
                }),
          ElevatedText(
              onPressed: () {
                AudioSourceRecorderPage(source: FlAudioSource.microphone).showModalPopup(context);
              },
              text: 'FlRecorder microphone'),
          ElevatedText(
              onPressed: () {
                AudioSourceRecorderPage(source: FlAudioSource.capture).showModalPopup(context);
              },
              text: 'FlRecorder capture'),
          ElevatedText(
              onPressed: () {
                RecorderMergePage().showModalPopup(context);
              },
              text: '麦克风和音频采集'),
        ]));
  }
}

class ElevatedText extends StatelessWidget {
  const ElevatedText({super.key, required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      ElevatedButton(onPressed: onPressed, child: Text(text));
}

extension WidgetExtension on Widget {
  Future<T?> showModalPopup<T>(BuildContext context) {
    return showCupertinoModalPopup(context: context, builder: (context) => this);
  }
}
