package com.mekaar.mekaar_chat

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MekaarCallActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MekaarCallAction"
        const val PREFS_NAME = "mekaar_call_actions"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val callId = intent.getStringExtra("callId")
        val notificationId = intent.getIntExtra("notificationId", -1)

        Log.d(TAG, "MekaarCallActionReceiver received action: $action, callId: $callId")

        // 1. Cancel Notifikasi Segera
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationId != -1) {
            notificationManager.cancel(notificationId)
        } else if (!callId.isNullOrEmpty()) {
            MekaarCallNotificationManager.cancelIncomingCall(context, callId)
        }

        // 2. Simpan status aksi decline ke SharedPreferences native
        // agar Flutter saat terbuka dapat membaca & mengirim sinyal decline ke backend Supabase
        if (!callId.isNullOrEmpty() && action == "com.mekaar.mekaar_chat.ACTION_DECLINE_CALL") {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString("declined_call_$callId", System.currentTimeMillis().toString()).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Gagal menyimpan declined call state", e)
            }
        }
    }
}
