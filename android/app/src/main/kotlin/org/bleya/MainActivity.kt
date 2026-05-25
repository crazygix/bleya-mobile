package com.bleyachat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureMessagesChannel()
    }

    private fun ensureMessagesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(MESSAGES_CHANNEL_ID) != null) {
            return
        }

        val channel = NotificationChannel(
            MESSAGES_CHANNEL_ID,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New messages and replies"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val MESSAGES_CHANNEL_ID = "bleya_messages"
    }
}
