import AudioRecorder from "./AudioRecorder";
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';

export default class ScreenCaptureRecorder extends AudioRecorder {
  private captureRecordConfig: media.AVScreenCaptureRecordConfig = {
    audioBitrate: this.audioSampleRate,
    audioSampleRate: this.audioSampleRate,
    audioChannelCount: this.audioChannels,
    // videoBitrate: this.audioSampleRate,
    // frameWidth: 100,
    // frameHeight: 100,
    fd: 0
  };
  // 创建录屏实例
  private screenCapture?: media.AVScreenCaptureRecorder;
  /// 文件缓存路径
  outputFilePath: string = this.context.cacheDir + '/fl_recorder_screen_capture.mp4';
  outputFile?: fs.File = undefined

  public async initialize(): Promise<boolean> {
    try {
      this.getEventChannel('capture')
      return this.flEventChannel != undefined
    } catch (error) {
      this.log(`initialize error: ${error} `)
    }
    return false
  }

  stateCode: media.AVScreenCaptureStateCode = media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED
  /// last is recording
  lastIsRecording: boolean = false
  /// 上次读取位置
  lastReadOffset: number = 0;
  /// 是否在录制
  isRecording: boolean = false

  public async startRecording(): Promise<boolean> {
    try {
      if (fs.accessSync(this.outputFilePath)) {
        fs.unlinkSync(this.outputFilePath)
      }
      this.outputFile =
        fs.openSync(this.outputFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      this.screenCapture = await media.createAVScreenCaptureRecorder();
      await this.screenCapture?.setMicEnabled(true).catch((error: BusinessError) => {
        this.log(`initialize setMicEnabled error: ${error} `)
      })
      this.screenCapture.on("stateChange", async (stateCode: media.AVScreenCaptureStateCode) => {
        this.stateCode = stateCode
        this.isRecording = stateCode == media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED
        if (this.isRecording != this.lastIsRecording) {
          this.sendState(this.isRecording)
        }
        if (this.isRecording) {
          this.readAudio()
        }
        this.lastIsRecording = this.isRecording
      })
      this.captureRecordConfig.fd = this.outputFile.fd
      await this.screenCapture.init(this.captureRecordConfig).catch((error: BusinessError) => {
        this.log(`initialize init error: ${error} `)
      })
      await this.screenCapture?.startRecording()
      return true
    } catch (error) {
      this.log(`stopRecording cache:${error}`)
    }
    return false
  }

  public async stopRecording(): Promise<boolean> {
    try {
      this.isRecording = false
      if (this.screenCapture) {
        this.screenCapture?.off("stateChange")
        await this.screenCapture?.stopRecording()
        await this.screenCapture?.release()
        this.screenCapture = undefined
      }
      this.sendState(this.isRecording)
      if (this.outputFile) {
        fs.closeSync(this.outputFile)
        this.outputFile = undefined
      }
      if (fs.accessSync(this.outputFilePath)) {
        fs.unlinkSync(this.outputFilePath)
      }
      this.lastReadOffset = 0
      return true
    } catch (error) {
      this.log(`stopRecording cache:${error}`)
    }
    return false
  }

  timer?: number = undefined

  // 创建Buffer容器 (根据搜索结果)
  readAudio() {
    this.timer = setInterval(async () => {
      try {
        if (!await fs.access(this.outputFilePath)) {
          return;
        }
        const fileSize = fs.statSync(this.outputFilePath).size
        // this.log(`=========${fileSize}======${this.lastReadOffset}===${this.isRecording}`)
        if (fileSize <= this.lastReadOffset) {
          if (!this.isRecording) {
            this.closeTimer()
          }
          return
        }
        const length = fileSize - this.lastReadOffset
        const readBuffer = new ArrayBuffer(length)
        const bytes = fs.readSync(
          this.outputFile!.fd,
          readBuffer,
          {
            offset: this.lastReadOffset,
            length
          }
        );
        if (bytes > 0) {
          this.lastReadOffset += bytes;
          this.sendBuffer(this.bufferSize, readBuffer)
        }
      } catch (error) {
        this.log(`readAudio cache:${error}`)
      }
    }, 50);
  }

  closeTimer() {
    clearInterval(this.timer);
    this.timer = undefined
  }

  public async dispose(): Promise<boolean> {
    try {
      this.closeTimer()
      await this.stopRecording()
      return true
    } catch (error) {
      this.log(`dispose error: ${error} `)
    }
    return false
  }
}