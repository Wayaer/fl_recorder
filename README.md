# fl_recorder

Using microphone recording and system audio capture on Flutter,The frontend service is enabled by default in Android, and resident message notifications have been added in Android Q and above

在Flutter上使用麦克风录音和系统音频捕获,在 android中默认启用了前台服务，并在 androidQ 以上添加了常驻消息通知

## Use

```dart


/// Initialize
void initialize() {
  FlAudioSource.microphone.recorder;
  FlAudioSource.capture.recorder;
}

/// Data stream
void onChanged() {
  FlAudioSource.microphone.recorder.onChanged((AudioDescription audio) {
    debugPrint("milliseconds:${audio.milliseconds}");
  });
}

/// Start recording
void startRecording() {
  FlAudioSource.microphone.recorder.startRecording();
}

/// Stop recording
void stopRecording() {
  FlAudioSource.microphone.recorder.stopRecording();
}

/// Dispose
void dispose() {
  FlAudioSource.microphone.recorder.dispose();
}

```