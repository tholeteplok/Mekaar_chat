package com.mekaar.mekaar_chat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object MekaarMessageNotificationManager {
    private const val TAG = "MekaarMsgNotif"
    const val MESSAGE_CHANNEL_ID = "mekaar_message_channel_v3"
    const val GROUP_MESSAGE_CHANNEL_ID = "mekaar_group_message_channel_v1"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            try {
                notificationManager.deleteNotificationChannel("mekaar_message_channel_v2")
                notificationManager.deleteNotificationChannel("mekaar_message_channel")
            } catch (_: Exception) {}

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .build()

            val personalChannel = NotificationChannel(
                MESSAGE_CHANNEL_ID,
                "Pesan MEKAAR",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Saluran notifikasi pesan masuk pribadi"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                enableLights(true)
                lightColor = Color.BLUE
                lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
            }
            notificationManager.createNotificationChannel(personalChannel)

            val groupChannel = NotificationChannel(
                GROUP_MESSAGE_CHANNEL_ID,
                "Pesan Grup MEKAAR",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Saluran notifikasi obrolan grup"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                enableLights(true)
                lightColor = Color.BLUE
                lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
            }
            notificationManager.createNotificationChannel(groupChannel)
        }
    }

    private fun getMessageNotificationId(roomId: String?): Int {
        val effectiveKey = if (!roomId.isNullOrEmpty()) "room_$roomId" else "mekaar_msg"
        val rawId = Math.abs(effectiveKey.hashCode()) % (1 shl 31)
        return if (rawId == 0) 1 else rawId
    }

    fun showMessageNotification(context: Context, data: Map<String, String>) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.d(TAG, "Notifikasi aplikasi dinonaktifkan di level OS/Pengaturan Sistem. Drop notifikasi pesan.")
            return
        }

        createChannel(context)

        val isGroup = data["isGroup"] == "true" || data["is_group"] == "true"
        val groupName = data["groupName"] ?: data["group_name"]

        // Jika notifikasi grup, periksa preferensi pengguna apakah notifikasi grup aktif
        if (isGroup) {
            val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val groupEnabled = sharedPrefs.getBoolean("flutter.group_notifications_enabled", true)
            if (!groupEnabled) {
                Log.d(TAG, "Notifikasi grup dinonaktifkan di setelan aplikasi. Drop notification.")
                return
            }
        }

        val targetChannelId = if (isGroup) GROUP_MESSAGE_CHANNEL_ID else MESSAGE_CHANNEL_ID

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = notificationManager.getNotificationChannel(targetChannelId)
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                Log.d(TAG, "Saluran pesan ($targetChannelId) dimatikan oleh pengguna di setelan OS.")
                return
            }
        }

        val roomId = data["roomId"] ?: data["room_id"]
        val senderId = data["senderId"] ?: data["sender_id"]
        val rawSenderName = data["senderName"] ?: data["sender_name"] ?: data["title"] ?: "Seseorang"
        val rawBody = data["body"] ?: data["content"] ?: "Pesan baru masuk"

        // Cek apakah ruang obrolan / pengirim berstatus Vault Terkunci
        val isVaultLocked = AegisNativeBridge.isRoomVaultLocked(context, roomId, senderId)

        val displayTitle: String
        val displayBody: String
        val summaryText: String

        if (isVaultLocked) {
            Log.d(TAG, "Pesan disamarkan (Vault Terkunci): roomId=$roomId")
            displayTitle = "MEKAAR"
            displayBody = "Pesan baru masuk"
            summaryText = "MEKAAR"
        } else {
            // Self-Healing: Jika server mengirim generic "MEKAAR" padahal kontak terbuka (!isVaultLocked),
            // prioritaskan senderName asli, atau gunakan "Pesan Baru" jika hanya ada nama brand MEKAAR.
            val candidateSenderName = data["senderName"] ?: data["sender_name"]
            val effectiveSenderName = when {
                !candidateSenderName.isNullOrEmpty() && candidateSenderName != "MEKAAR" -> candidateSenderName
                rawSenderName != "MEKAAR" -> rawSenderName
                else -> "Pesan Baru"
            }
            if (isGroup) {
                displayTitle = if (!groupName.isNullOrEmpty()) groupName else "Grup MEKAAR"
                displayBody = "$effectiveSenderName: $rawBody"
                summaryText = if (!groupName.isNullOrEmpty()) groupName else "Grup MEKAAR"
                Log.d(TAG, "Pesan grup ditampilkan Rich: group=$displayTitle, sender=$effectiveSenderName, roomId=$roomId")
            } else {
                displayTitle = effectiveSenderName
                displayBody = rawBody
                summaryText = "MEKAAR"
                Log.d(TAG, "Pesan pribadi ditampilkan Rich: sender=$effectiveSenderName, roomId=$roomId")
            }
        }

        val notificationId = getMessageNotificationId(roomId)

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_VIEW_ROOM"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("roomId", roomId)
            putExtra("senderId", senderId)
            putExtra("senderName", if (isVaultLocked) null else rawSenderName)
            putExtra("isGroup", isGroup)
            putExtra("groupName", if (isVaultLocked) null else groupName)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val builder = NotificationCompat.Builder(context, targetChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayTitle)
            .setContentText(displayBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(displayBody).setSummaryText(summaryText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(if (isVaultLocked) NotificationCompat.VISIBILITY_SECRET else NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setColor(0xFF007AFF.toInt())
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setGroup(if (!roomId.isNullOrEmpty()) "room_$roomId" else "mekaar_group")
            .setContentIntent(pendingIntent)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }

    fun cancelMessageNotification(context: Context, roomId: String?) {
        val notificationId = getMessageNotificationId(roomId)
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Batalkan notifikasi berbasis integer ID tanpa tag (dari MekaarMessageNotificationManager & FlutterLocalNotifications)
        notificationManager.cancel(notificationId)

        // 2. Batalkan notifikasi bertag FCM (Google Play Services default tag: "msg_$roomId")
        if (!roomId.isNullOrEmpty()) {
            notificationManager.cancel("msg_$roomId", 0)
            notificationManager.cancel("msg_$roomId", notificationId)
            notificationManager.cancel("room_$roomId", 0)
            notificationManager.cancel("room_$roomId", notificationId)
        }
    }

    fun cancelAllMessageNotifications(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            notificationManager.cancelAll()
        } catch (_: Exception) {}
    }
}
