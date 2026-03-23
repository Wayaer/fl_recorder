package fl.recorder

import android.content.Context
import android.media.AudioRecord

class RecordAudioRecorder(context: Context, val audioSource: Int) : AudioRecorder(context) {

    override fun initialize(): Boolean {
        getEventChannel("record")
        if (mRecorder == null) {
            if (checkSelfPermission()) {
                bufferSize = AudioRecord.getMinBufferSize(
                    RECORDER_SAMPLE_RATE, RECORDER_CHANNELS, RECORDER_AUDIO_ENCODING
                )
                mRecorder = AudioRecord(
                    audioSource,
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