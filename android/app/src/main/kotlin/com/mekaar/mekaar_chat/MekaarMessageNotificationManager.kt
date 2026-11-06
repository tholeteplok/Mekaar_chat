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

            val channel = NotificationChannel(
                MESSAGE_CHANNEL_ID,
                "Pesan MEKAAR",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Saluran notifikasi pesan masuk"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                enableLights(true)
                lightColor = Color.BLUE
                lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
            }
            notificationManager.createNotificationChannel(channel)
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = notificationManager.getNotificationChannel(MESSAGE_CHANNEL_ID)
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                Log.d(TAG, "Saluran pesan dimatikan oleh pengguna di setelan OS.")
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

        if (isVaultLocked) {
            Log.d(TAG, "Pesan disamarkan (Vault Terkunci): roomId=$roomId")
            displayTitle = "MEKAAR"
            displayBody = "Pesan baru masuk"
        } else {
            // Self-Healing: Jika server mengirim generic "MEKAAR" padahal kontak terbuka (!isVaultLocked),
            // prioritaskan senderName asli, atau gunakan "Pesan Baru" jika hanya ada nama brand MEKAAR.
            val candidateSenderName = data["senderName"] ?: data["sender_name"]
            val effectiveSenderName = when {
                !candidateSenderName.isNullOrEmpty() && candidateSenderName != "MEKAAR" -> candidateSenderName
                rawSenderName != "MEKAAR" -> rawSenderName
                else -> "Pesan Baru"
            }
            Log.d(TAG, "Pesan ditampilkan Rich: sender=$effectiveSenderName, roomId=$roomId")
            displayTitle = effectiveSenderName
            displayBody = rawBody
        }

        val notificationId = getMessageNotificationId(roomId)

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_VIEW_ROOM"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("roomId", roomId)
            putExtra("senderId", senderId)
            putExtra("senderName", if (isVaultLocked) null else rawSenderName)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val builder = NotificationCompat.Builder(context, MESSAGE_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(displayTitle)
            .setContentText(displayBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(displayBody).setSummaryText("MEKAAR"))
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
        notificationManager.cancel(notificationId)
    }
}
