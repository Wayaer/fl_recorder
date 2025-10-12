package fl.recorder

import android.annotation.SuppressLint
import android.app.*
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.IBinder

class ScreenCaptureAudioRecordService : NotificationService() {

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var mMediaProjectionCallback: MediaProjectionCallback? = null
    private var mediaProjection: MediaProjection? = null

    override fun onCreate() {
        super.onCreate()
        mediaProjectionManager =
            getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    private val binder = ScreenCaptureAudioRecordServiceBinder()

    inner class ScreenCaptureAudioRecordServiceBinder : Binder() {
        fun getService(): ScreenCaptureAudioRecordService {
            return this@ScreenCaptureAudioRecordService
        }
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        val resultData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("resultData", Intent::class.java)
        } else {
            intent.getParcelableExtra("resultData")
        }
        resultData?.let {
            mMediaProjectionCallback = MediaProjectionCallback()
            mediaProjection =
                mediaProjectionManager.getMediaProjection(Activity.RESULT_OK, resultData)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && mediaProjection != null) {
                mRecorder = ScreenCaptureAudioRecorder(this)
                mRecorder!!.initialize(mediaProjection!!)
            } else {
                mediaProjection?.stop()
                stopSelf()
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }


    override fun startRecording(): Boolean {
        return mRecorder?.startRecording() == true
    }

    override fun stopRecording(): Boolean {
        return mRecorder?.stopRecording() == true
    }


    override fun onDestroy() {
        dispose()
        super.onDestroy()
    }

    @SuppressLint("WrongConstant")
    override fun dispose() {
        super.dispose()
        mMediaProjectionCallback?.let { mediaProjection?.unregisterCallback(it) }
        mediaProjection?.stop()
        mediaProjection = null
    }


    companion object {
        fun getIntent(context: Context): Intent {
            return Intent(context, ScreenCaptureAudioRecordService::class.java)
        }
    }

    inner class MediaProjectionCallback : MediaProjection.Callback() {
        override fun onStop() {
            dispose()
        }
    }
}
