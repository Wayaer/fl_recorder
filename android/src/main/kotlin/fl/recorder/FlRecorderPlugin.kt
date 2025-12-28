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
    private var recordAudioRecorder: RecordAudioRecorderService? = null
    private var recordAudioServiceConnection: ServiceConnection? = null
    private var recordResult: MethodChannel.Result? = null
    private val recordPermissionRequestCode = 1000

    // 系统录音
    private var screenCaptureRecorderService: ScreenCaptureRecorderService? = null
    private var screenCaptureRecorderServiceConnection: ServiceConnection? = null
    private var screenCaptureResult: MethodChannel.Result? = null
    private val screenCaptureRequestCode = 666

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val source = call.argument<Int>("source")
                if (source == 0) {
                    if (recordAudioRecorder != null) {
                        result.success(true)
                        return
                    }
                    this.recordResult = result
                } else if (source == 1) {
                    if (screenCaptureRecorderService != null) {
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
                    0 -> recordAudioRecorder?.startRecording()
                    1 -> screenCaptureRecorderService?.startRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "stopRecording" -> {
                val source = call.argument<Int>("source")
                val value = when (source) {
                    0 -> recordAudioRecorder?.stopRecording()
                    1 -> screenCaptureRecorderService?.stopRecording()
                    else -> null
                }
                result.success(value == true)
            }

            "dispose" -> {
                try {
                    val source = call.argument<Int>("source")
                    if (source == 0) {
                        context.stopService(RecordAudioRecorderService.getIntent(context))
                        recordAudioServiceConnection?.let {
                            activityBinding.activity.unbindService(it)
                        }
                        recordAudioRecorder = null
                        recordAudioServiceConnection = null
                    } else if (source == 1) {
                        context.stopService(ScreenCaptureRecorderService.getIntent(context))
                        screenCaptureRecorderServiceConnection?.let {
                            activityBinding.activity.unbindService(it)
                        }
                        screenCaptureRecorderService = null
                        screenCaptureRecorderServiceConnection = null
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
            requestCode = recordPermissionRequestCode
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
                val intent = ScreenCaptureRecorderService.getIntent(context)
                intent.putExtra("resultData", data)
                screenCaptureRecorderServiceConnection = FlServiceConnection(1)
                startForegroundService(intent, 1, screenCaptureRecorderServiceConnection!!)
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
            if (requestCode == recordPermissionRequestCode) {
                recordAudioServiceConnection = FlServiceConnection(0)
                startForegroundService(
                    RecordAudioRecorderService.getIntent(context), 0, recordAudioServiceConnection!!
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
                recordResult?.success(true)
                recordResult = null
                val binder =
                    service as RecordAudioRecorderService.MicrophoneAudioRecordServiceBinder
                recordAudioRecorder = binder.getService()
            } else if (source == 1) {
                screenCaptureResult?.success(true)
                screenCaptureResult = null
                val binder =
                    service as ScreenCaptureRecorderService.ScreenCaptureAudioRecordServiceBinder
                screenCaptureRecorderService = binder.getService()
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            if (source == 0) {
                recordAudioRecorder?.dispose()
                recordAudioRecorder = null
            } else if (source == 1) {
                screenCaptureRecorderService?.dispose()
                screenCaptureRecorderService = null
            }
        }
    }


}
