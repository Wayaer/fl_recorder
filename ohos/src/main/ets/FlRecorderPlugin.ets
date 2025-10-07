import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';

export default class FlRecorderPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private abilityBinding: AbilityPluginBinding | null = null
  private pluginBinding: FlutterPluginBinding | null = null
  static logTag = 'FlRecorderPlugin:'

  constructor() {
  }

  getUniqueClassName(): string {
    return "FlRecorderPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "fl.recorder");
    this.channel.setMethodCallHandler(this)
    this.pluginBinding = binding
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
    this.pluginBinding = null
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding
  }

  onDetachedFromAbility(): void {
    this.abilityBinding = null
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'exitApp':
        this.pluginBinding?.getApplicationContext().getApplicationContext().killAllProcesses()
        result.success(true)
        break;
      default:
        result.notImplemented()
    }
  }
}
