package fl.recorder

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Context.MEDIA_PROJECTION_SERVICE
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry


/** FlRecorderPlugin */
class FlRecorderPlugin : FlutterPlugin, MethodCallHandler, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener, ActivityAware {
    private lateinit var channel: MethodChannel

    private lateinit var context: Context
    private lateinit var activityBinding: ActivityPluginBinding

    private val isIgnoringBatteryOptimizationsCode = 888
    private val mediaProjectionPermissionRequestCode = 10001


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fl.recorder")
        channel.setMethodCallHandler(this)
    }

    private var isIgnoringBatteryResult: MethodChannel.Result? = null

    // 麦克风
    private var microphoneAudioRecordService: MicrophoneAudioRecordService? = null
    private var microphoneAudioServiceConnection: ServiceConnection? = null
    private var microphoneResult: MethodChannel.Result? = null
    private val microphonePermissionRequestCode = 1000

    // 系统录音
    private var screenCaptureAudioRecordService: ScreenCaptureAudioRecordService? = null
    private var screenCaptureAudioServiceConnection: ServiceConnection? = null
    private var screenCaptureResult: MethodChannel.Result? = null
    private val screenCaptureRequestCode = 666

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val source = call.argument<Int>("source")
                if (source == 0) {
                    if (microphoneAudioRecordService != null) {
                        result.success(true)
                        return
                    }
                    this.microphoneResult = result
                } else if (source == 1) {
                    if (screenCaptureAudioRecordService != null) {
                        result.success(true)
                        return
                    }
                    this.screenCaptureResult = result
                }
                initialize(result, source)
            }

            "startRecording" -> {
                val source = call.argument<Int>("source")
                val value = when (source) {
                    0 -> microphoneAudioRecordService?.startRecording()
                    1 -> screenCaptureAudioRecordService?.startRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "stopRecording" -> {
                val source = call.argument<Int>("source")
                val value = when (source) {
                    0 -> microphoneAudioRecordService?.stopRecording()
                    1 -> screenCaptureAudioRecordService?.stopRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "dispose" -> {
                try {
                    val source = call.argument<Int>("source")
                    if (source == 0) {
                        context.stopService(MicrophoneAudioRecordService.getIntent(context))
                        microphoneAudioServiceConnection?.let {
                            activityBinding.activity.unbindService(it)
                        }
                        microphoneAudioRecordService = null
                        microphoneAudioServiceConnection = null
                    } else if (source == 1) {
                        context.stopService(ScreenCaptureAudioRecordService.getIntent(context))
                        screenCaptureAudioServiceConnection?.let {
                            activityBinding.activity.unbindService(it)
                        }
                        screenCaptureAudioRecordService = null
                        screenCaptureAudioServiceConnection = null
                    }
                    result.success(source != null)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (!isIgnoringBatteryOptimizations()) {
                    isIgnoringBatteryResult = result
                    requestIgnoreBatteryOptimizations()
                    return
                }
                result.success(true)
            }

            else -> result.success(null)
        }
    }


    private fun initialize(result: MethodChannel.Result, source: Int?) {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            permissions.add(Manifest.permission.FOREGROUND_SERVICE)
        }
        var requestCode: Int? = null
        if (source == 0) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                permissions.add(Manifest.permission.FOREGROUND_SERVICE_MICROPHONE)
            }
            requestCode = microphonePermissionRequestCode
        } else if (source == 1) {
            permissions.add(Manifest.permission.CAPTURE_AUDIO_OUTPUT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                permissions.add(Manifest.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION)
            }
            requestCode = mediaProjectionPermissionRequestCode
        }
        requestCode?.let {
            ActivityCompat.requestPermissions(
                activityBinding.activity, permissions.toTypedArray(), it
            )
        } ?: result.success(false)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    @SuppressLint("BatteryLife")
    private fun requestIgnoreBatteryOptimizations() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.setData(("package:" + context.packageName).toUri())
            activityBinding.activity.startActivityForResult(
                intent, isIgnoringBatteryOptimizationsCode
            )
        } catch (e: java.lang.Exception) {
            e.printStackTrace()
        }
    }


    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (resultCode == Activity.RESULT_OK) {
            if (requestCode == screenCaptureRequestCode) {
                val intent = ScreenCaptureAudioRecordService.getIntent(context)
                intent.putExtra("resultData", data)
                screenCaptureAudioServiceConnection = FlServiceConnection(1)
                startForegroundService(intent, 1, screenCaptureAudioServiceConnection!!)
            }
        }
        if (requestCode == isIgnoringBatteryOptimizationsCode) {
            isIgnoringBatteryResult?.success(isIgnoringBatteryOptimizations())
            isIgnoringBatteryResult = null
        }
        return false
    }

    private fun startForegroundService(intent: Intent, source: Int, conn: ServiceConnection) {
        ContextCompat.startForegroundService(context, intent)
        activityBinding.activity.bindService(
            intent, conn, Context.BIND_AUTO_CREATE
        )
    }


    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            if (requestCode == microphonePermissionRequestCode) {
                microphoneAudioServiceConnection = FlServiceConnection(0)
                startForegroundService(
                    MicrophoneAudioRecordService.getIntent(context),
                    0,
                    microphoneAudioServiceConnection!!
                )
            } else if (requestCode == mediaProjectionPermissionRequestCode) {
                val mProjectionManager =
                    context.getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val intent = mProjectionManager.createScreenCaptureIntent()
                activityBinding.activity.startActivityForResult(
                    intent, screenCaptureRequestCode
                )
            }
        }
        return false
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding.removeActivityResultListener(this)
        activityBinding.removeRequestPermissionsResultListener(this)
    }

    private inner class FlServiceConnection(
        private val source: Int
    ) : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            if (source == 0) {
                microphoneResult?.success(true)
                microphoneResult = null
                val binder =
                    service as MicrophoneAudioRecordService.MicrophoneAudioRecordServiceBinder
                microphoneAudioRecordService = binder.getService()
            } else if (source == 1) {
                screenCaptureResult?.success(true)
                screenCaptureResult = null
                val binder =
                    service as ScreenCaptureAudioRecordService.ScreenCaptureAudioRecordServiceBinder
                screenCaptureAudioRecordService = binder.getService()
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            if (source == 0) {
                microphoneAudioRecordService?.dispose()
                microphoneAudioRecordService = null
            } else if (source == 1) {
                screenCaptureAudioRecordService?.dispose()
                screenCaptureAudioRecordService = null
            }
        }
    }


}
