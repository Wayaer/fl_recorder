package fl.recorder

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder

class MicrophoneAudioRecordService : NotificationService() {
    private val binder = MicrophoneAudioRecordServiceBinder()

    inner class MicrophoneAudioRecordServiceBinder : Binder() {
        fun getService(): MicrophoneAudioRecordService {
            return this@MicrophoneAudioRecordService
        }
    }


    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        mRecorder = AudioRecorder(this)
        mRecorder!!.initializeMicrophoneAudioRecord()
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
        destroy()
        super.onDestroy()
    }

    companion object {
        fun getIntent(context: Context): Intent {
            return Intent(context, MicrophoneAudioRecordService::class.java)
        }
    }
}
