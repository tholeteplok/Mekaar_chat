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

object MekaarCallNotificationManager {
    const val CALL_CHANNEL_ID = "mekaar_calls_channel_v2"
    const val MISSED_CALL_CHANNEL_ID = "mekaar_missed_calls_channel_v2"
    private const val CALL_NOTIFICATION_BASE_ID = 40001
    private const val MISSED_CALL_BASE_ID = 50001

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 1. Channel Panggilan Masuk (High Priority, Ringtone, Vibration)
            val callChannel = NotificationChannel(
                CALL_CHANNEL_ID,
                "Panggilan Masuk MEKAAR",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi dan dering prioritas tinggi untuk panggilan suara dan video MEKAAR"
                val defaultRingtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .build()
                setSound(defaultRingtoneUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 1000, 1000, 1000, 1000)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(callChannel)

            // 2. Channel Panggilan Tak Terjawab (Default Importance)
            val missedChannel = NotificationChannel(
                MISSED_CALL_CHANNEL_ID,
                "Panggilan Tak Terjawab",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notifikasi saat ada panggilan MEKAAR yang tidak terjawab"
                enableVibration(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
            }
            notificationManager.createNotificationChannel(missedChannel)
        }
    }

    private fun getCallNotificationId(callId: String?): Int {
        return if (!callId.isNullOrEmpty()) {
            CALL_NOTIFICATION_BASE_ID + (callId.hashCode() and 0x7FFF)
        } else {
            CALL_NOTIFICATION_BASE_ID
        }
    }

    private fun getMissedCallNotificationId(callId: String?): Int {
        return if (!callId.isNullOrEmpty()) {
            MISSED_CALL_BASE_ID + (callId.hashCode() and 0x7FFF)
        } else {
            MISSED_CALL_BASE_ID
        }
    }

    fun showIncomingCall(context: Context, data: Map<String, String>) {
        createChannels(context)

        val callId = data["callId"] ?: data["call_id"] ?: ""
        val roomId = data["roomId"] ?: data["room_id"] ?: ""
        val callerId = data["callerId"] ?: data["caller_id"] ?: ""
        val callerName = data["callerName"] ?: "Seseorang"
        val callType = data["callType"] ?: "voice"
        val isVideo = callType.equals("video", ignoreCase = true)
        val typeLabel = if (isVideo) "Panggilan Video" else "Panggilan Suara"

        val notificationId = getCallNotificationId(callId)

        // 1. Full-Screen & Content Intent (Tap banner / Wake screen)
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_VIEW_CALL"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("callId", callId)
            putExtra("roomId", roomId)
            putExtra("callerId", callerId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("isIncomingCall", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Answer Intent
        val answerIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_ANSWER_CALL"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("callId", callId)
            putExtra("roomId", roomId)
            putExtra("callerId", callerId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("callAction", "answer")
        }
        val answerPendingIntent = PendingIntent.getActivity(
            context,
            notificationId + 1,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 3. Decline Intent (handled by native receiver without launching UI)
        val declineIntent = Intent(context, MekaarCallActionReceiver::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_DECLINE_CALL"
            putExtra("callId", callId)
            putExtra("roomId", roomId)
            putExtra("callerId", callerId)
            putExtra("notificationId", notificationId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val defaultRingtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        val builder = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(callerName)
            .setContentText("$typeLabel masuk...")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setSound(defaultRingtoneUri)
            .setVibrate(longArrayOf(0, 1000, 1000, 1000, 1000, 1000))
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Tolak",
                declinePendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_call,
                "Terima",
                answerPendingIntent
            )

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }

    fun cancelIncomingCall(context: Context, callId: String?) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(getCallNotificationId(callId))
    }

    fun showMissedCall(context: Context, data: Map<String, String>) {
        createChannels(context)

        val callId = data["callId"] ?: data["call_id"] ?: ""
        val roomId = data["roomId"] ?: data["room_id"] ?: ""
        val callerName = data["callerName"] ?: "Seseorang"
        val callType = data["callType"] ?: "voice"
        val isVideo = callType.equals("video", ignoreCase = true)
        val typeLabel = if (isVideo) "Panggilan Video" else "Panggilan Suara"

        val notificationId = getMissedCallNotificationId(callId)

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.mekaar.mekaar_chat.ACTION_VIEW_ROOM"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("roomId", roomId)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, MISSED_CALL_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Panggilan Tak Terjawab")
            .setContentText("$callerName ($typeLabel)")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }
}
