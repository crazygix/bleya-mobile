package com.bleyachat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast
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
        registerSystemMessageChannel(flutterEngine)
    }

    /** The toast on screen, which the next message replaces. */
    private var shownToast: Toast? = null

    /**
     * The app's short messages ("Passkey added.", "Couldn't open the link.")
     * for the Dart side (`SystemMessage`): `show` on the `bleya/messages`
     * channel shows one as a system toast, drawn by Android in the phone's own
     * look. A new message replaces the one on screen.
     */
    private fun registerSystemMessageChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_MESSAGES_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "show") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val message = call.argument<String>("message")
                if (message.isNullOrEmpty()) {
                    result.error("invalid-message", "A message needs its text.", null)
                    return@setMethodCallHandler
                }
                shownToast?.cancel()
                shownToast = Toast.makeText(applicationContext, message, Toast.LENGTH_LONG)
                    .also { it.show() }
                result.success(null)
            }
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
     * Firebase Messaging showed for pushes. `clearChat` removes only one
     * chat's. `showBanner` shows a push that arrived while the app is open.
     */
    private fun registerNotificationTrayChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearAll" -> {
                        notificationManager().cancelAll()
                        result.success(null)
                    }
                    "clearChat" -> {
                        clearChat(call.argument<String>("roomId"), call.argument<String>("threadId"))
                        result.success(null)
                    }
                    "showBanner" -> {
                        val messageId = call.argument<String>("messageId")
                        if (messageId.isNullOrEmpty()) {
                            result.error("invalid-banner", "A banner needs the push's message id.", null)
                            return@setMethodCallHandler
                        }
                        showBanner(
                            messageId = messageId,
                            title = call.argument<String>("title") ?: "",
                            body = call.argument<String>("body") ?: "",
                            sentTime = call.argument<Number>("sentTime")?.toLong(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Removes the notifications of one chat: a room's new messages, or a
     * thread's replies. The backend tags each push `room:<roomId>:<messageId>`
     * or `thread:<threadId>:<messageId>`; other chats' notifications stay.
     */
    private fun clearChat(roomId: String?, threadId: String?) {
        val prefixes = listOfNotNull(roomId?.let { "room:$it:" }, threadId?.let { "thread:$it:" })
        if (prefixes.isEmpty()) {
            return
        }
        val manager = notificationManager()
        for (shown in manager.activeNotifications) {
            val tag = shown.tag ?: continue
            if (prefixes.any { tag.startsWith(it) }) {
                manager.cancel(tag, shown.id)
            }
        }
    }

    private fun notificationManager() =
        applicationContext.getSystemService(NOTIFICATION_SERVICE) as NotificationManager

    /**
     * Shows a push that arrived while the app is open, which Firebase doesn't
     * show then, as a heads-up notification on the Messages channel. It is
     * built like the ones Firebase shows while the app is closed (same icon,
     * title, body and sound) and sets no accent colour, so the system draws it
     * in the phone's own light or dark look, not the app's. It removes itself
     * once seen, so none pile up in the shade while the app is open. Its tap
     * carries `google.message_id`, as Firebase's own do, so Firebase Messaging
     * reports it as opened and the app opens the chat.
     */
    private fun showBanner(messageId: String, title: String, body: String, sentTime: Long?) {
        val manager = notificationManager()
        if (!manager.areNotificationsEnabled()) {
            return
        }

        val notificationId = messageId.hashCode()
        val tap = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("google.message_id", messageId)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            notificationId,
            tap,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, MESSAGES_CHANNEL_ID)
                .setTimeoutAfter(BANNER_LIFETIME_MS)
        } else {
            // No channels before Android 8: high priority with sound and
            // vibration makes it a heads-up.
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_ALL)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setWhen(sentTime ?: System.currentTimeMillis())
            .setShowWhen(true)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        manager.notify(notificationId, notification)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Handler(Looper.getMainLooper()).postDelayed(
                { manager.cancel(notificationId) },
                BANNER_LIFETIME_MS,
            )
        }
    }

    companion object {
        private const val MESSAGES_CHANNEL_ID = "bleya_messages"
        private const val NOTIFICATIONS_CHANNEL = "bleya/notifications"
        private const val SYSTEM_MESSAGES_CHANNEL = "bleya/messages"

        /** A heads-up shows for about 5 s; the banner leaves the shade soon after. */
        private const val BANNER_LIFETIME_MS = 8_000L
    }
}
