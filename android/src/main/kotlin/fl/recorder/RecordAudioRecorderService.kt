package fl.recorder

import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder

class RecordAudioRecorderService : NotificationService() {
    private val binder = MicrophoneAudioRecordServiceBinder()

    inner class MicrophoneAudioRecordServiceBinder : Binder() {
        fun getService(): RecordAudioRecorderService {
            return this@RecordAudioRecorderService
        }
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        mRecorder = RecordAudioRecorder(this)
        mRecorder!!.initialize()
        return super.onStartCommand(intent, flags, startId)
    }

    override fun startRecording(): Boolean {
        return mRecorder?.startRecording() == true
    }

    override fun stopRecording(): Boolean {
        return mRecorder?.stopRecording() == true
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onDestroy() {
        dispose()
        super.onDestroy()
    }

    companion object Companion {
        fun getIntent(context: Context): Intent {
            return Intent(context, RecordAudioRecorderService::class.java)
        }
    }
}
