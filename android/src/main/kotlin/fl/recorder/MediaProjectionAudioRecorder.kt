package fl.recorder

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build

class MediaProjectionAudioRecorder(context: Context) : AudioRecorder(context) {

    override fun initialize(mProjection: MediaProjection): Boolean {
        getEventChannel("capture")
        if (mRecorder == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (checkSelfPermission()) {
                val config = AudioPlaybackCaptureConfiguration.Builder(mProjection)
                    // 媒体类
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)

                    // 通信类（电话相关）
//                    .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
//                    .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
//                    .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_MEDIA)

                    // 通知类
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_REQUEST)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_DELAYED)
                    .addMatchingUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)

                    // 辅助功能类
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .addMatchingUsage(AudioAttributes.USAGE_ASSISTANT)

                    // 系统与警报类
                    .addMatchingUsage(AudioAttributes.USAGE_ALARM)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)


                    // 未知类型
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
        return super.initialize(mProjection)
    }

}