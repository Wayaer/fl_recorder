import { audio } from '@kit.AudioKit'
import AudioRecorder from './AudioRecorder'
import { available } from './FlRecorderPlugin'
import { common } from '@kit.AbilityKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'

export default class RecordAudioRecorder extends AudioRecorder {
  sourceType: audio.SourceType = audio.SourceType.SOURCE_TYPE_MIC

  constructor(context: common.UIAbilityContext, sourceType?: audio.SourceType) {
    super(context)
    if (sourceType) {
      this.sourceType = sourceType
    }
  }

  private audioStreamInfo: audio.AudioStreamInfo = {
    samplingRate: this.audioSampleRate,
    encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    channels: this.audioChannels,
    sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
  }
  /// 录音工具
  private audioCapturer?: audio.AudioCapturer
  /// last is recording
  lastIsRecording: boolean = false

  public async initialize(): Promise<boolean> {
    try {
      const permission = this.requestPermission(['ohos.permission.MICROPHONE'])
      if (!permission) {
        return permission
      }
      this.getEventChannel('record')
      if (this.audioCapturer == undefined) {
        this.audioCapturer = await audio.createAudioCapturer({
          streamInfo: this.audioStreamInfo,
          capturerInfo: {
            source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
            capturerFlags: 0,
          }
        })
        this.audioCapturer.on('stateChange', (state: audio.AudioState) => {
          const isRecording = state == audio.AudioState.STATE_RUNNING
          if (isRecording != this.lastIsRecording) {
            this.sendState(isRecording)
          }
          this.lastIsRecording = isRecording
        })
        this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
          this.sendBuffer(this.bufferSize, buffer)
        })
        this.bufferSize = this.audioCapturer.getBufferSizeSync()
      }
    } catch (error) {
      this.log(`initialize error: ${error} `)
    }
    return this.audioCapturer != undefined
  }


  /// 开始采集
  public async startRecording(): Promise<boolean> {
    try {
      await this.startBackgroundRunning(backgroundTaskManager.BackgroundMode.AUDIO_RECORDING);
      await this.audioCapturer?.start()
    } catch (error) {
      this.log(`startRecording cache:${error}`)
    }
    return this.audioCapturer != undefined
  }

  /// 停止采集
  public async stopRecording(): Promise<boolean> {
    try {
      await this.stopBackgroundRunning()
      await this.audioCapturer?.stop()
    } catch (error) {
      this.log(`stopRecording cache:${error}`)
    }
    return this.audioCapturer != undefined
  }

  /// 释放前 先调用 stop
  public async dispose(): Promise<boolean> {
    try {
      this.audioCapturer?.off('readData')
      await this.stopRecording()
      if (available(18)) {
        this.audioCapturer?.off("stateChange")
      }
      await this.audioCapturer?.release()
      this.audioCapturer = undefined
      return true
    } catch (error) {
      this.log(`dispose cache:${error}`)
      return false
    }
  }
}