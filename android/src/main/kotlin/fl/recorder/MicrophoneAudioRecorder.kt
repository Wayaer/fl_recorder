package fl.recorder

import android.content.Context
import android.media.AudioRecord
import android.media.MediaRecorder


class MicrophoneAudioRecorder(context: Context) : AudioRecorder(context) {

    override fun initialize(): Boolean {
        getEventChannel("microphone")
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
        return super.initialize()
    }
}