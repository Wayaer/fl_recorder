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
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import androidx.core.net.toUri


/** FlRecorderPlugin */
class FlRecorderPlugin : FlutterPlugin, MethodCallHandler, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener, ActivityAware {
    private lateinit var channel: MethodChannel

    private lateinit var context: Context

    private val screenCaptureIRequestCode = 666
    private val isIgnoringBatteryOptimizationsCode = 888
    private val microphonePermissionRequestCode = 1000
    private val mediaProjectionPermissionRequestCode = 10001

    private var result: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fl.recorder")
        channel.setMethodCallHandler(this)
    }

    //  0 麦克风 1 系统录音
    private var source = 0

    // 麦克风
    private var microphoneAudioRecordService: MicrophoneAudioRecordService? = null

    // 系统录音
    private var mediaProjectionAudioRecordService: MediaProjectionAudioRecordService? = null

    private lateinit var activityBinding: ActivityPluginBinding

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                this.result = result
                source = call.argument<Int>("source") ?: 0
                if (microphoneAudioRecordService != null || mediaProjectionAudioRecordService != null) {
                    result.success(false)
                    return
                }
                initialize()
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (!isIgnoringBatteryOptimizations()) {
                    this.result = result
                    requestIgnoreBatteryOptimizations()
                    return
                }
                result.success(true)
            }

            "startRecording" -> {
                val value = if (source == 0) {
                    microphoneAudioRecordService?.startRecording()
                } else {
                    mediaProjectionAudioRecordService?.startRecording()
                }
                result.success(value == true)
            }

            "stopRecording" -> {
                val value = if (source == 0) {
                    microphoneAudioRecordService?.stopRecording()
                } else {
                    mediaProjectionAudioRecordService?.stopRecording()
                }
                result.success(value == true)
            }

            "dispose" -> {
                try {
                    if (microphoneAudioRecordService != null) {
                        context.stopService(MicrophoneAudioRecordService.getIntent(context))
                        microphoneAudioRecordService = null
                    }
                    if (mediaProjectionAudioRecordService != null) {
                        context.stopService(MediaProjectionAudioRecordService.getIntent(context))
                        mediaProjectionAudioRecordService = null
                    }
                    activityBinding.activity.unbindService(serviceConnection)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            else -> result.success(null)
        }
    }

    private fun initialize() {
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
        }

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


    private val serviceConnection = object : ServiceConnection {
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
            mediaProjectionAudioRecordService = null
            microphoneAudioRecordService = null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (resultCode == Activity.RESULT_OK) {
            if (requestCode == screenCaptureIRequestCode && source == 1) {
                val intent = MediaProjectionAudioRecordService.getIntent(context)
                intent.putExtra("resultData", data)
                startForegroundService(intent)
            }
        }
        if (requestCode == isIgnoringBatteryOptimizationsCode) {
            result?.success(isIgnoringBatteryOptimizations())
            result = null
        }
        return false
    }

    private fun startForegroundService(intent: Intent) {
        if (source == 1) intent.putExtra("source", source)
        ContextCompat.startForegroundService(context, intent)
        activityBinding.activity.bindService(
            intent, serviceConnection, Context.BIND_AUTO_CREATE
        )
    }


    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            if (requestCode == microphonePermissionRequestCode) {
                startForegroundService(MicrophoneAudioRecordService.getIntent(context))
            } else if (requestCode == mediaProjectionPermissionRequestCode) {
                val mProjectionManager =
                    context.getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val screenCaptureIntent = mProjectionManager.createScreenCaptureIntent()
                activityBinding.activity.startActivityForResult(
                    screenCaptureIntent, screenCaptureIRequestCode
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
}
