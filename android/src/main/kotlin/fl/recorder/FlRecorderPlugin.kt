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

    private val screenCaptureRequestCode = 666
    private val isIgnoringBatteryOptimizationsCode = 888
    private val microphonePermissionRequestCode = 1000
    private val mediaProjectionPermissionRequestCode = 10001

    private var result: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fl.recorder")
        channel.setMethodCallHandler(this)
    }


    // 麦克风
    private var microphoneAudioRecordService: MicrophoneAudioRecordService? = null

    // 系统录音
    private var mediaProjectionAudioRecordService: MediaProjectionAudioRecordService? = null


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                this.result = result
                val source = call.argument<Int>("source")
                if (source == 0 && microphoneAudioRecordService != null) {
                    result.success(true)
                    return
                } else if (source == 1 && mediaProjectionAudioRecordService != null) {
                    result.success(true)
                    return
                }
                initialize(result, source)
            }

            "startRecording" -> {
                val source = call.argument<Int>("source")
                val value = when (source) {
                    0 -> microphoneAudioRecordService?.startRecording()
                    1 -> mediaProjectionAudioRecordService?.startRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "stopRecording" -> {
                val source = call.argument<Int>("source")
                val value = when (source) {
                    0 -> microphoneAudioRecordService?.stopRecording()
                    1 -> mediaProjectionAudioRecordService?.stopRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "dispose" -> {
                try {
                    val source = call.argument<Int>("source")
                    if (source == 0) {
                        context.stopService(MicrophoneAudioRecordService.getIntent(context))
                        microphoneAudioRecordService = null
                    } else if (source == 1) {
                        context.stopService(MediaProjectionAudioRecordService.getIntent(context))
                        mediaProjectionAudioRecordService = null
                    }
                    source?.let { activityBinding.activity.unbindService(FlServiceConnection(it)) }
                    result.success(source != null)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (!isIgnoringBatteryOptimizations()) {
                    this.result = result
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
                val intent = MediaProjectionAudioRecordService.getIntent(context)
                intent.putExtra("resultData", data)
                startForegroundService(intent, 1)
            }
        }
        if (requestCode == isIgnoringBatteryOptimizationsCode) {
            result?.success(isIgnoringBatteryOptimizations())
            result = null
        }
        return false
    }

    private fun startForegroundService(intent: Intent, source: Int) {
        intent.putExtra("source", source)
        ContextCompat.startForegroundService(context, intent)
        activityBinding.activity.bindService(
            intent, FlServiceConnection(source), Context.BIND_AUTO_CREATE
        )
    }


    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            if (requestCode == microphonePermissionRequestCode) {
                startForegroundService(MicrophoneAudioRecordService.getIntent(context), 0)
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
            result?.success(true)
            result = null
            if (source == 0) {
                val binder =
                    service as MicrophoneAudioRecordService.MicrophoneAudioRecordServiceBinder
                microphoneAudioRecordService = binder.getService()
            } else if (source == 1) {
                val binder =
                    service as MediaProjectionAudioRecordService.MediaProjectionAudioRecordServiceBinder
                mediaProjectionAudioRecordService = binder.getService()
            }

        }

        override fun onServiceDisconnected(name: ComponentName?) {
            if (source == 0) {
                microphoneAudioRecordService = null
            } else if (source == 1) {
                mediaProjectionAudioRecordService = null
            }
        }
    }
}
