package com.bleyachat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureMessagesChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Registers the plugins.
        super.configureFlutterEngine(flutterEngine)
        registerNotificationTrayChannel(flutterEngine)
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

    /**
     * The app's notifications in the notification shade and on the lock
     * screen, for the Dart side (`NotificationTrayService`): `clearAll` on
     * the `bleya/notifications` channel removes them, including the ones
     * Firebase Messaging showed for pushes.
     */
    private fun registerNotificationTrayChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "clearAll") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val manager =
                    applicationContext.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                manager.cancelAll()
                result.success(null)
            }
    }

    companion object {
        private const val MESSAGES_CHANNEL_ID = "bleya_messages"
        private const val NOTIFICATIONS_CHANNEL = "bleya/notifications"
    }
}
