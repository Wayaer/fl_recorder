package fl.recorder

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import fl.channel.FlChannelPlugin
import fl.channel.FlEventChannel
import java.io.FileNotFoundException
import java.io.IOException

class AudioRecorder(private val context: Context) {
    private var isRecording: Boolean = false
    private var mRecorder: AudioRecord? = null

    private var recordingThread: Thread? = null
    private var bufferSize = 1024

    companion object {
        const val TAG: String = "FlRecorder:"
        private const val RECORDER_SAMPLE_RATE = 16000
        private const val RECORDER_CHANNELS = AudioFormat.CHANNEL_IN_MONO
        private const val RECORDER_AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var flEventChannel: FlEventChannel? = null

    fun getFlEventChannel() {
        if (flEventChannel == null) {
            flEventChannel = FlChannelPlugin.getEventChannel("fl.recorder.event")
        }
    }

    fun initializeMicrophoneAudioRecord(): Boolean {
        getFlEventChannel()
        if (mRecorder == null) {
            if (checkSelfPermission()) {
                bufferSize = AudioRecord.getMinBufferSize(
                    RECORDER_SAMPLE_RATE, RECORDER_CHANNELS, RECORDER_AUDIO_ENCODING
                )
                mRecorder = AudioRecord(
                    MediaRecorder.AudioSource.DEFAULT,
                    RECORDER_SAMPLE_RATE,
                    RECORDER_CHANNELS,
                    RECORDER_AUDIO_ENCODING,
                    bufferSize
                )
            }
        }
        return this.mRecorder != null
    }

    fun initializeMediaProjectionAudioRecord(mProjection: MediaProjection?): Boolean {
        getFlEventChannel()
        if (mRecorder == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (checkSelfPermission()) {
                val config = AudioPlaybackCaptureConfiguration.Builder(mProjection!!)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .addMatchingUsage(AudioAttributes.USAGE_ALARM)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANT)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN).build()
                val format = AudioFormat.Builder().setEncoding(RECORDER_AUDIO_ENCODING)
                    .setSampleRate(RECORDER_SAMPLE_RATE).setChannelMask(RECORDER_CHANNELS).build()
                bufferSize = AudioRecord.getMinBufferSize(
                    RECORDER_SAMPLE_RATE, RECORDER_CHANNELS, RECORDER_AUDIO_ENCODING
                )
                mRecorder =
                    AudioRecord.Builder().setAudioFormat(format).setBufferSizeInBytes(bufferSize)
                        .setAudioPlaybackCaptureConfig(config).build()
            }
        }
        return mRecorder != null
    }

    private fun checkSelfPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED;
    }

    fun startRecording(): Boolean {
        if (isRecording) return false
        isRecording = true
        flEventChannel?.send(true)
        mRecorder?.startRecording()
        if (mRecorder != null) {
            recordingThread = null
            recordingThread = Thread({ writeAudioFile() }, "fl_recorder Audio Recording")
            recordingThread?.start()
        }
        return mRecorder != null
    }

    fun stopRecording(): Boolean {
        isRecording = false
        mRecorder?.stop()
        flEventChannel?.send(false)
        return mRecorder != null
    }


    fun destroy() {
        stopRecording()
        mRecorder?.release()
        mRecorder = null
        recordingThread = null
        flEventChannel = null
    }

    private fun writeAudioFile() {
        try {
            val byte = ByteArray(bufferSize)
            mRecorder!!.read(byte, 0, bufferSize)
            while (isRecording) {
                flEventChannel?.send(
                    mapOf(
                        "byte" to byte
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception: $e")
            e.printStackTrace()
        }
    }
}
