package com.mekaar.mekaar_chat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat

object MekaarSosNotificationManager {
    const val SOS_CHANNEL_ID = "mekaar_sos_channel_v2"
    private const val SOS_NOTIFICATION_BASE_ID = 60001

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val sosChannel = NotificationChannel(
                SOS_CHANNEL_ID,
                "Sinyal Darurat SOS MEKAAR",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Peringatan darurat instan dan alarm bahaya SOS MEKAAR"
                val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setSound(alarmUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 1000)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(sosChannel)
        }
    }

    fun showSosAlert(context: Context, data: Map<String, String>) {
        createChannel(context)

        val senderName = data["senderName"] ?: data["sender_name"] ?: "Kontak Terpercaya"
        val alertId = data["alertId"] ?: data["alert_id"] ?: System.currentTimeMillis().toString()
        val lat = data["latitude"] ?: data["lat"] ?: ""
        val lng = data["longitude"] ?: data["lng"] ?: ""

        val notificationId = SOS_NOTIFICATION_BASE_ID + (alertId.hashCode() and 0x7FFF)

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_VIEW_SOS"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("alertId", alertId)
            putExtra("senderName", senderName)
            putExtra("lat", lat)
            putExtra("lng", lng)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        val builder = NotificationCompat.Builder(context, SOS_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🚨 PERINGATAN DARURAT (SOS)")
            .setContentText("$senderName memicu sinyal darurat SOS!")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setSound(alarmUri)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 1000))
            .addAction(
                android.R.drawable.ic_dialog_map,
                "Lihat Lokasi",
                pendingIntent
            )

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }
}
