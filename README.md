# fl_recorder

Currently only supports Android, and iOS will be supported in the future

目前仅支持Android，未来将支持iOS

Using microphone recording and system audio capture on Flutter,The frontend service is enabled by default in Android, and resident message notifications have been added in Android Q and above

在Flutter上使用麦克风录音和系统音频捕获,在 android中默认启用了前台服务，并在 androidQ 以上添加了常驻消息通知

## Use
```dart


/// Initialize
void initialize() {
  FlRecorder().initialize(source: AudioSource.capture);
  FlRecorder().initialize(source: AudioSource.microphone);
}

/// Data stream
void onChanged() {
  FlRecorder().onChanged((AudioDescription audio) {
    debugPrint("milliseconds:${audio.milliseconds}");
  });
}

/// Start recording
void startRecording() {
  FlRecorder().startRecording();
}

/// Stop recording
void stopRecording() {
  FlRecorder().stopRecording();
}

/// Dispose
void dispose() {
  FlRecorder().dispose();
}

```