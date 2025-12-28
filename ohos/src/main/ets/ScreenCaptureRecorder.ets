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
  filePath: string = this.context.cacheDir + '/fl_recorder_screen_capture.mp4';
  file?: fs.File = undefined

  public async initialize(): Promise<boolean> {
    try {
      this.getEventChannel('capture')
      if (fs.accessSync(this.filePath)) {
        fs.unlinkSync(this.filePath)
      }
      this.log(this.filePath)
      this.file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      this.captureRecordConfig.fd = this.file.fd
      this.screenCapture = await media.createAVScreenCaptureRecorder();
      await this.screenCapture.init(this.captureRecordConfig).catch((error: BusinessError) => {
        this.log(`initialize init error: ${error} `)
      })
      this.screenCapture.on("stateChange", (stateCode: media.AVScreenCaptureStateCode) => {
        this.stateCode = stateCode
        const isRecording = stateCode == media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED
        if (isRecording != this.lastIsRecording) {
          this.sendState(isRecording)
        }
        if (isRecording) {
          this.readAudio()
        }
        this.lastIsRecording = isRecording
      })
      return this.screenCapture != undefined
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

  public async startRecording(): Promise<boolean> {
    if (this.screenCapture) {
      try {
        await this.screenCapture?.startRecording()
        return true
      } catch (error) {
        this.log(`stopRecording cache:${error}`)
      }
    }
    return false
  }

  timer?: number = undefined

  // 创建Buffer容器 (根据搜索结果)
  async readAudio() {
    if (this.file) {
      this.timer = setInterval(() => {
        try {
          const fileSize = fs.statSync(this.filePath).size
          if (fileSize <= this.lastReadOffset) {
            return
          }
          const length = fileSize - this.lastReadOffset
          const readBuffer = new ArrayBuffer(length)
          const bytes = fs.readSync(
            this.file!.fd,
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
  }

  public async stopRecording(): Promise<boolean> {
    try {
      await this.screenCapture?.stopRecording()
      return true
    } catch (error) {
      this.log(`stopRecording cache:${error}`)
    }
    return false
  }

  public async dispose(): Promise<boolean> {
    try {
      clearInterval(this.timer);
      this.timer = undefined
      this.screenCapture?.off("stateChange")
      await this.stopRecording()
      await this.screenCapture?.release()
      fs.closeSync(this.file)
      await fs.unlink(this.filePath)
      this.file = undefined
      this.screenCapture = undefined
      return true
    } catch (error) {
      this.log(`dispose error: ${error} `)
    }
    return false
  }
}