package com.mekaar.mekaar_chat

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.security.SecureRandom

object AegisNativeBridge {
    private const val TAG = "AegisNativeBridge"
    private const val PREFS_NAME = "mekaar_aegis_security"
    private const val KEY_PUSH_SECRET = "push_decryption_key_v1"
    private var isLibraryLoaded = false

    init {
        try {
            System.loadLibrary("mekaar_aegis_core")
            isLibraryLoaded = true
            Log.i(TAG, "Library native mekaar_aegis_core berhasil dimuat")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Gagal memuat library native mekaar_aegis_core: ${e.message}", e)
            isLibraryLoaded = false
        }
    }

    /**
     * JNI binding ke fungsi Rust:
     * `Java_com_mekaar_mekaar_1chat_AegisNativeBridge_decryptPayload`
     */
    @JvmStatic
    external fun decryptPayload(
        ciphertext: ByteArray,
        nonce: ByteArray,
        key: ByteArray
    ): String?

    /**
     * Menyimpan kunci dekripsi push 32-byte (Base64) yang disinkronkan oleh Flutter saat login.
     */
    fun setPushDecryptionKey(context: Context, keyBase64: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_PUSH_SECRET, keyBase64).apply()
        Log.i(TAG, "Kunci dekripsi push berhasil diperbarui di penyimpanan native")
    }

    /**
     * Mengambil kunci dekripsi 32-byte untuk push E2EE.
     * Jika belum ada kunci dari login, membuat dan menyimpan kunci acak perangkat sebagai fallback.
     */
    fun getOrCreatePushKey(context: Context): ByteArray {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedKeyB64 = prefs.getString(KEY_PUSH_SECRET, null)
        if (!savedKeyB64.isNullOrEmpty()) {
            try {
                val decoded = Base64.decode(savedKeyB64, Base64.DEFAULT)
                if (decoded.size == 32) {
                    return decoded
                }
            } catch (e: Exception) {
                Log.w(TAG, "Format kunci push tersimpan tidak valid: ${e.message}")
            }
        }

        // Buat kunci acak 32-byte baru jika belum ada
        val randomKey = ByteArray(32)
        SecureRandom().nextBytes(randomKey)
        val newKeyB64 = Base64.encodeToString(randomKey, Base64.NO_WRAP)
        prefs.edit().putString(KEY_PUSH_SECRET, newKeyB64).apply()
        return randomKey
    }

    /**
     * Mendekripsi payload push FCM yang dienkripsi dengan ChaCha20-Poly1305.
     * Menerima string Base64 dari server dan mengembalikan data map hasil dekripsi.
     */
    fun decryptPushPayload(
        ciphertextB64: String,
        nonceB64: String,
        keyBytes: ByteArray
    ): Map<String, String>? {
        if (!isLibraryLoaded) {
            Log.w(TAG, "Library native belum termuat, dekripsi dilewati")
            return null
        }

        return try {
            val ciphertext = Base64.decode(ciphertextB64, Base64.DEFAULT)
            val nonce = Base64.decode(nonceB64, Base64.DEFAULT)

            val decryptedJsonString = decryptPayload(ciphertext, nonce, keyBytes)
            if (decryptedJsonString.isNullOrEmpty()) {
                Log.w(TAG, "Dekripsi payload gagal atau MAC Poly1305 tidak valid")
                return null
            }

            val jsonObject = JSONObject(decryptedJsonString)
            val resultMap = mutableMapOf<String, String>()
            val keys = jsonObject.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                resultMap[k] = jsonObject.optString(k, "")
            }
            resultMap
        } catch (e: Exception) {
            Log.e(TAG, "Error saat mendekripsi payload push: ${e.message}", e)
            null
        }
    }
}
