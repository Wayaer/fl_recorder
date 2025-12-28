package fl.recorder

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.media.projection.MediaProjection
import android.util.Log
import androidx.core.app.ActivityCompat
import fl.channel.FlChannelPlugin
import fl.channel.FlEventChannel
import kotlin.math.abs
import kotlin.math.log10

abstract class AudioRecorder(private val context: Context) {
    open var isRecording: Boolean = false
    open var mRecorder: AudioRecord? = null

    open var recordingThread: Thread? = null
    open var bufferSize = 1024

    companion object {
        const val TAG: String = "FlRecorder:"
        const val RECORDER_SAMPLE_RATE = 16000
        const val RECORDER_CHANNELS = AudioFormat.CHANNEL_IN_MONO
        const val RECORDER_AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var flEventChannel: FlEventChannel? = null

    fun getEventChannel(source: String) {
        if (flEventChannel == null) {
            flEventChannel = FlChannelPlugin.getEventChannel("fl.recorder.event.${source}")
        }
    }

    open fun initialize(mProjection: MediaProjection): Boolean {
        return this.mRecorder != null
    }

    open fun initialize(): Boolean {
        return this.mRecorder != null
    }

    open fun checkSelfPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun startRecording(): Boolean {
        if (isRecording) return false
        isRecording = true
        sendData(true)
        mRecorder?.startRecording()
        if (mRecorder != null) {
            recordingThread = null
            recordingThread = Thread({ sendBuffer() }, "System Audio Recording")
            recordingThread?.start()
        }
        return mRecorder != null
    }

    fun stopRecording(): Boolean {
        isRecording = false
        mRecorder?.stop()
        sendData(false)
        return mRecorder != null
    }

    fun dispose() {
        stopRecording()
        mRecorder?.release()
        mRecorder = null
        recordingThread = null
        flEventChannel = null
    }


    private fun sendBuffer() {
        try {
            val byte = ByteArray(bufferSize)
            while (isRecording) {
                val readSize = mRecorder!!.read(byte, 0, bufferSize)
                sendData(
                    mapOf("byte" to byte, "decibel" to getNormalizedDecibel(readSize, byte))
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "send exception: $e")
        }
    }

    fun sendData(args: Any) {
        flEventChannel?.send(args)
    }

    private fun getNormalizedDecibel(readSize: Int, byte: ByteArray): Double {
        val referenceAmp = 32768.0 // 16位音频的最大值
        val maxDecibels = 100.0
        var maxAmplitude = 0
        for (i in 0 until readSize step 2) {
            val sample = (byte[i + 1].toInt() shl 8) or (byte[i].toInt() and 0xff)
            maxAmplitude = maxOf(maxAmplitude, abs(sample))
        }
        if (maxAmplitude == 0) return 0.0
        val dB = 20 * log10(maxAmplitude / referenceAmp)
        return maxOf(0.0, minOf(1.0, dB / maxDecibels + 1))
    }

}
