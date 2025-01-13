package fl.recorder

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Build
import android.os.IBinder

open class NotificationService : Service() {

    override fun onCreate() {
        initNotification()
        super.onCreate()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    var mRecorder: AudioRecorder? = null

    private val notificationId = 999
    private val channelID = "notificationChannelID"
    private val title = "录音服务"
    private val content = "录音服务正在运行..."
    private val description = "AudioRecordService"

    /**
     * 初始化通知栏
     */
    private fun initNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(channelID, title, NotificationManager.IMPORTANCE_HIGH)
            channel.enableLights(true) //设置提示灯
            channel.lightColor = Color.RED //设置提示灯颜色
            channel.setShowBadge(true) //显示logo
            channel.description = description
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC //设置锁屏可见 VISIBILITY_PUBLIC=可见
            manager.createNotificationChannel(channel)
            val builder = Notification.Builder(this, channelID)
            val notification = builder.setAutoCancel(false).setContentTitle(title) //标题
                .setContentText(content) //内容
                .setWhen(System.currentTimeMillis()).setSmallIcon(R.mipmap.ic_launcher) //设置小图标
                .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))//设置大图标
                .build()
            startForeground(notificationId, notification)
        }
    }

    @SuppressLint("WrongConstant")
    open fun destroy() {
        mRecorder?.destroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            stopForeground(notificationId)
        }
    }

    open fun startRecording(): Boolean {
        return false

    }

    open fun stopRecording(): Boolean {
        return false
    }

}