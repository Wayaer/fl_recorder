import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import deviceInfo from '@ohos.deviceInfo';
import RecordAudioRecorder from './RecordAudioRecorder';
import ScreenCaptureRecorder from './ScreenCaptureRecorder';

const TAG = 'FlRecorderPlugin'

export default class FlRecorderPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel?: MethodChannel
  private abilityBinding?: AbilityPluginBinding
  private pluginBinding?: FlutterPluginBinding

  constructor() {
  }

  getUniqueClassName(): string {
    return TAG
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "fl.recorder");
    this.channel.setMethodCallHandler(this)
    this.pluginBinding = binding
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != undefined) {
      this.channel.setMethodCallHandler(null)
    }
    this.pluginBinding = undefined
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding
  }

  onDetachedFromAbility(): void {
    this.abilityBinding = undefined
  }

  // 录制音频
  private recordAudioRecorder?: RecordAudioRecorder
  // 屏幕录制
  private screenCaptureRecorder?: ScreenCaptureRecorder

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'initialize': {
        let source = call.argument("source") as number
        let sourceType = call.argument("sourceType") as number
        const context = this.abilityBinding?.getAbility().context
        if (context == undefined) {
          result.success(false)
          return
        }
        if (source == 0) {
          this.recordAudioRecorder = new RecordAudioRecorder(context, sourceType)
          result.success(await this.recordAudioRecorder.initialize())
        } else if (source == 1 && available(14)) {
          this.screenCaptureRecorder = new ScreenCaptureRecorder(context)
          result.success(await this.screenCaptureRecorder.initialize())
        } else {
          result.success(false)
        }
      }
        break;
      case 'startRecording': {
        let source = call.argument("source") as number
        try {
          if (source == 0 && this.recordAudioRecorder) {
            this.recordAudioRecorder.startRecording().then((value) => {
              result.success(value)
            });
          } else if (source == 1 && this.screenCaptureRecorder) {
            this.screenCaptureRecorder.startRecording().then((value) => {
              result.success(value)
            });
          } else {
            throw Error()
          }
        } catch (e) {
          this.log(e)
          result.success(false)
        }
      }
        break;
      case 'stopRecording': {
        let source = call.argument("source") as number
        try {
          if (source == 0 && this.recordAudioRecorder) {
            this.recordAudioRecorder.stopRecording().then((value) => {
              result.success(value)
            });
          } else if (source == 1 && this.screenCaptureRecorder) {
            this.screenCaptureRecorder.stopRecording().then((value) => {
              result.success(value)
            });
          } else {
            throw Error()
          }
        } catch (e) {
          this.log(e)
          result.success(false)
        }
      }
        break;
      case 'dispose': {
        let source = call.argument("source") as number
        try {
          if (source == 0 && this.recordAudioRecorder) {
            await this.recordAudioRecorder.dispose().then((value) => {
              result.success(value)
            });
            this.recordAudioRecorder = undefined
          } else if (source == 1 && this.screenCaptureRecorder) {
            await this.screenCaptureRecorder.dispose().then((value) => {
              result.success(value)
            });
            this.screenCaptureRecorder = undefined
          } else {
            throw Error()
          }
        } catch (e) {
          this.log(e)
          result.success(false)
        }
      }
        break;
      default:
        result.notImplemented()
    }
  }

  public log(format: string, ...args: Object[]) {
    Log.d(TAG, format, args)
  }
}

export function available(level: number): boolean {
  let sdkApiVersionInfo: number = deviceInfo.sdkApiVersion;
  if (sdkApiVersionInfo >= level) {
    return true
  }
  return false
}