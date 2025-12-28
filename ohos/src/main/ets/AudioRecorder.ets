import { Log } from "@ohos/flutter_ohos"
import FlChannelPlugin from "fl_channel"
import FlEventChannel from "fl_channel/src/main/ets/FlEventChannel"
import { abilityAccessCtrl, Permissions } from "@kit.AbilityKit"
import { audio } from "@kit.AudioKit"

export default class AudioRecorder {
  TAG: string = "FlRecorderPlugin"
  /// audioSampleRate
  audioSampleRate: number = audio.AudioSamplingRate.SAMPLE_RATE_16000
  /// audioChannels
  audioChannels: number = audio.AudioChannel.CHANNEL_1
  ///
  public context: Context
  /// buffer size
  bufferSize: number = 1024

  constructor(context: Context) {
    this.context = context
  }

  /// event
  flEventChannel?: FlEventChannel = undefined

  public getEventChannel(source: string) {
    this.flEventChannel = FlChannelPlugin.getEventChannel(`fl.recorder.event.${source}`)
  }

  public log(format: string, ...args: Object[]) {
    Log.d(this.TAG, format, args)
  }

  public async initialize(): Promise<boolean> {
    return Promise.resolve(false)
  }

  public async startRecording(): Promise<boolean> {
    return Promise.resolve(false)
  }

  public sendState(isRecording: boolean): boolean {
    try {
      return this.flEventChannel?.send(isRecording) ?? false
    } catch (e) {
      this.log(`send state error: ${e}`)
    }
    return false
  }

  public sendBuffer(readSize: number, buffer: ArrayBuffer): boolean {
    try {
      const byte = new Uint8Array(buffer)
      return this.flEventChannel?.send({
        "byte": byte,
        "decibel": this.getNormalizedDecibel(readSize, byte)
      }) ?? false
    } catch (e) {
      this.log(`send buffer error: ${e}`)
    }
    return false
  }

  getNormalizedDecibel(readSize: number, byte: Uint8Array): number {
    const referenceAmp: number = 32768.0; // 16位音频的最大振幅值
    const maxDecibels: number = 100.0; // 最大分贝参考值

    let maxAmplitude: number = 0;

    // 遍历音频数据，每2个字节组成一个16位样本
    for (let i = 0; i < readSize - 1; i += 2) {
      // 组合字节：小端序 (低位在前)
      const lowByte: number = byte[i] & 0xFF;
      const highByte: number = byte[i + 1] << 8;
      const sample: number = highByte | lowByte;

      // 转换为有符号16位整数
      const signedSample: number = sample > 0x7FFF ? sample - 0x10000 : sample;
      const absSample: number = Math.abs(signedSample);
      maxAmplitude = Math.max(maxAmplitude, absSample);
    }

    // 处理静音情况
    if (maxAmplitude === 0) {
      return 0.0;
    }

    // 计算分贝值并归一化
    const dB: number = 20 * Math.log10(maxAmplitude / referenceAmp);
    const normalized: number = dB / maxDecibels + 1;

    // 限制在 [0.0, 1.0] 范围
    return Math.max(0.0, Math.min(1.0, normalized));
  }


  public async stopRecording(): Promise<boolean> {
    return Promise.resolve(false)
  }

  public async dispose(): Promise<boolean> {
    return Promise.resolve(false)
  }

  async requestPermission(permissionList: Array<Permissions>): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const data = await atManager.requestPermissionsFromUser(this.context, permissionList)
      const grantStatus: number[] = data.authResults;
      let isGrant = true
      grantStatus.forEach((v, i) => {
        isGrant = v == 0
        this.log(`权限申请 [${permissionList[i]}] ：${isGrant}`);
      })
      return isGrant
    } catch (e) {
      this.log(`权限申请失败 [${permissionList.join(',')}] ：${e}`);
    }
    return false
  }
}