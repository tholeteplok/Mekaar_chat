package com.mekaar.mekaar_chat

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver

/**
 * Custom BroadcastReceiver yang memotong sinyal push FCM sebelum menyalakan Dart VM.
 *
 * Mendukung dekripsi Zero-Trust E2EE via Rust Core (AegisNativeBridge):
 * - Jika payload push dienkripsi oleh server (encrypted_payload + nonce), didekripsi secara
 *   lokal oleh Rust Core (ChaCha20-Poly1305) sebelum dieksekusi.
 *
 * Untuk sinyal berprioritas kritis seperti 'call' dan 'sos':
 * - Langsung dieksekusi oleh native notification manager (<10ms).
 * - Tidak memicu inisialisasi Dart Isolate / Flutter Engine di background saat panggilan berdering,
 *   sehingga kebal dari pemutusan paksa (LMK kill) oleh OS Android vendor tertentu (Xiaomi/Oppo/Vivo).
 *
 * Untuk tipe pesan teks / obrolan umum ('message'):
 * - Diteruskan secara transparan ke super class (FlutterFirebaseMessagingReceiver)
 *   untuk diproses oleh background worker Flutter standar.
 */
class MekaarFirebaseMessagingReceiver : FlutterFirebaseMessagingReceiver() {
    companion object {
        private const val TAG = "MekaarFCMReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras
        if (extras == null) {
            super.onReceive(context, intent)
            return
        }

        val remoteMessage = try {
            RemoteMessage(extras)
        } catch (e: Exception) {
            Log.e(TAG, "Gagal mengurai RemoteMessage dari intent extras", e)
            super.onReceive(context, intent)
            return
        }

        var data = remoteMessage.data

        // 1. Deteksi & Dekripsi Zero-Trust E2EE (ChaCha20-Poly1305 via Rust Aegis Core)
        val encryptedPayload = data["encrypted_payload"] ?: data["ciphertext"]
        val nonce = data["nonce"] ?: data["iv"]

        if (!encryptedPayload.isNullOrEmpty() && !nonce.isNullOrEmpty()) {
            Log.d(TAG, "Payload push terenkripsi terdeteksi, mendekripsi via Rust Core JNI...")
            val pushKey = AegisNativeBridge.getOrCreatePushKey(context)
            val decryptedData = AegisNativeBridge.decryptPushPayload(encryptedPayload, nonce, pushKey)

            if (decryptedData != null) {
                Log.i(TAG, "Payload push E2EE berhasil didekripsi via Rust Aegis Core")
                val mergedData = data.toMutableMap()
                mergedData.putAll(decryptedData)
                data = mergedData
            } else {
                Log.w(TAG, "Gagal mendekripsi payload push E2EE (Integritas MAC gagal atau kunci tidak cocok)")
            }
        }

        val type = data["type"] ?: "message"
        Log.d(TAG, "MekaarFCMReceiver memproses push bertipe: $type")

        when (type) {
            "call" -> {
                val status = data["status"] ?: "calling"
                val callId = data["callId"] ?: data["call_id"]

                when (status) {
                    "calling" -> {
                        Log.d(TAG, "Menampilkan notifikasi panggilan masuk native 0ms (CallId: $callId)")
                        MekaarCallNotificationManager.showIncomingCall(context, data)
                    }
                    "ended", "declined", "failed" -> {
                        Log.d(TAG, "Membatalkan notifikasi panggilan native (CallId: $callId, Status: $status)")
                        MekaarCallNotificationManager.cancelIncomingCall(context, callId)
                    }
                    "missed" -> {
                        Log.d(TAG, "Menampilkan notifikasi missed call native (CallId: $callId)")
                        MekaarCallNotificationManager.cancelIncomingCall(context, callId)
                        MekaarCallNotificationManager.showMissedCall(context, data)
                    }
                }

                // PENTING: Jangan panggil super.onReceive untuk 'call' agar Dart VM Isolate
                // tidak dibangunkan secara sia-sia di background saat panggilan sedang berdering.
                return
            }

            "sos" -> {
                Log.d(TAG, "Menampilkan notifikasi darurat SOS native segera")
                MekaarSosNotificationManager.showSosAlert(context, data)

                // Teruskan juga ke Dart agar state sinkronisasi darurat di database berjalan
                super.onReceive(context, intent)
            }

            else -> {
                // Delegasikan ke pipeline Flutter standar untuk pesan chat & notifikasi umum
                super.onReceive(context, intent)
            }
        }
    }
}
