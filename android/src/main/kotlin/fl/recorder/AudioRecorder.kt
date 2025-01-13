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
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.ByteBuffer
import kotlin.math.log10
import kotlin.math.sqrt

class AudioRecorder(private val context: Context) {
    private var isRecording: Boolean = false
    private var mRecorder: AudioRecord? = null

    private var recordingThread: Thread? = null
    private var bufferSize = 1024

    companion object {
        const val TAG: String = "System Audio Recording"
        private const val RECORDER_SAMPLE_RATE = 16000
        private const val RECORDER_CHANNELS = AudioFormat.CHANNEL_IN_MONO
        private const val RECORDER_AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    fun initializeMicrophoneAudioRecord(): Boolean {
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
                    .addMatchingUsage(AudioAttributes.USAGE_GAME).addMatchingUsage(AudioAttributes.USAGE_ASSISTANT)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN).build()
                val format =
                    AudioFormat.Builder().setEncoding(RECORDER_AUDIO_ENCODING).setSampleRate(RECORDER_SAMPLE_RATE)
                        .setChannelMask(RECORDER_CHANNELS).build()
                bufferSize = AudioRecord.getMinBufferSize(
                    RECORDER_SAMPLE_RATE, RECORDER_CHANNELS, RECORDER_AUDIO_ENCODING
                )
                mRecorder = AudioRecord.Builder().setAudioFormat(format).setBufferSizeInBytes(bufferSize)
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
        startTime = System.currentTimeMillis()
        isRecording = true
        FlChannelPlugin.flEvent?.send(true)
        mRecorder?.startRecording()
        if (mRecorder != null) {
            recordingThread = null
            recordingThread = Thread({ writeAudioFile() }, "System Audio Recording")
            recordingThread?.start()
        }
        return mRecorder != null
    }

    fun stopRecording(): Boolean {
        if (!isRecording) return false
        isAddTime = false
        isRecording = false
        mRecorder?.stop()
        accumulatedTime += System.currentTimeMillis() - startTime!!
        FlChannelPlugin.flEvent?.send(false)
        return mRecorder != null
    }


    fun destroy() {
        stopRecording()
        mRecorder?.release()
        mRecorder = null
        recordingThread = null
        accumulatedTime = 0
    }


    private var accumulatedTime: Long = 0
    private var startTime: Long? = null
    private var isAddTime = false;

    private fun shortToByte(data: ShortArray): ByteArray {
        val arraySize = data.size
        val bytes = ByteArray(arraySize * 2)
        for (i in 0 until arraySize) {
            bytes[i * 2] = (data[i].toInt() and 0x00FF).toByte()
            bytes[i * 2 + 1] = (data[i].toInt() shr 8).toByte()
            data[i] = 0
        }
        return bytes
    }

    private fun writeAudioFile() {
        try {
            val byte = ByteArray(bufferSize)
            while (isRecording) {
                val length = mRecorder!!.read(byte, 0, bufferSize)
                val currentTime = System.currentTimeMillis()
                var time = currentTime - startTime!!
                time += accumulatedTime
                FlChannelPlugin.flEvent?.send(
                    mapOf(
                        "byte" to byte,
                        "timeMillis" to time,
                        "length" to length,
                    )
                )
            }
        } catch (e: FileNotFoundException) {
            Log.e(TAG, "File Not Found: $e")
            e.printStackTrace()
        } catch (e: IOException) {
            Log.e(TAG, "IO Exception: $e")
            e.printStackTrace()
        }
    }
}
