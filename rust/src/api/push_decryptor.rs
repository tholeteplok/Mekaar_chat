use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce, XChaCha20Poly1305, XNonce};
use zeroize::Zeroize;

/// Mendekripsi payload push terenkripsi (Zero-Trust E2EE) menggunakan ChaCha20-Poly1305 atau XChaCha20-Poly1305.
/// 
/// Parameter:
/// - `ciphertext`: Raw bytes ciphertext yang menyertakan tag Poly1305 16-byte di ujungnya.
/// - `nonce`: Nonce 24-byte (XChaCha20) atau 12-byte (ChaCha20).
/// - `key`: Kunci simetris 32-byte (256-bit AES/ChaCha equivalent).
/// 
/// Menghasilkan plaintext JSON string jika otentikasi tag Poly1305 valid, atau error jika ciphertext rusak/dimanipulasi.
pub fn decrypt_push_payload(
    ciphertext: &[u8],
    nonce: &[u8],
    key: &[u8],
) -> Result<String, String> {
    if key.len() != 32 {
        return Err(format!("Panjang kunci harus tepat 32 bytes, diterima: {}", key.len()));
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(key);

    let result = match nonce.len() {
        24 => {
            // XChaCha20-Poly1305 (24-byte extended nonce)
            let cipher_key = Key::from_slice(&key_bytes);
            let cipher = XChaCha20Poly1305::new(cipher_key);
            let xnonce = XNonce::from_slice(nonce);

            cipher.decrypt(xnonce, ciphertext)
                .map_err(|e| format!("Gagal mendekripsi payload XChaCha20-Poly1305 (Integritas MAC gagal): {}", e))
        }
        12 => {
            // ChaCha20-Poly1305 standar (12-byte nonce)
            let cipher_key = Key::from_slice(&key_bytes);
            let cipher = ChaCha20Poly1305::new(cipher_key);
            let std_nonce = Nonce::from_slice(nonce);

            cipher.decrypt(std_nonce, ciphertext)
                .map_err(|e| format!("Gagal mendekripsi payload ChaCha20-Poly1305 (Integritas MAC gagal): {}", e))
        }
        _ => {
            key_bytes.zeroize();
            return Err(format!("Panjang nonce tidak valid (harus 12 atau 24 bytes), diterima: {}", nonce.len()));
        }
    };

    // Bersihkan buffer kunci di memori segera setelah proses kriptografi selesai
    key_bytes.zeroize();

    let decrypted_bytes = result?;
    let decrypted_string = String::from_utf8(decrypted_bytes)
        .map_err(|e| format!("Hasil dekripsi bukan teks UTF-8 yang valid: {}", e))?;

    Ok(decrypted_string)
}

/// Mengenkripsi plaintext JSON menjadi ciphertext terotentikasi (AEAD).
/// Digunakan oleh server edge function atau pengujian integritas end-to-end.
pub fn encrypt_push_payload(
    plaintext: &str,
    nonce: &[u8],
    key: &[u8],
) -> Result<Vec<u8>, String> {
    if key.len() != 32 {
        return Err(format!("Panjang kunci harus tepat 32 bytes, diterima: {}", key.len()));
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(key);

    let result = match nonce.len() {
        24 => {
            let cipher_key = Key::from_slice(&key_bytes);
            let cipher = XChaCha20Poly1305::new(cipher_key);
            let xnonce = XNonce::from_slice(nonce);

            cipher.encrypt(xnonce, plaintext.as_bytes())
                .map_err(|e| format!("Gagal mengenkripsi XChaCha20: {}", e))
        }
        12 => {
            let cipher_key = Key::from_slice(&key_bytes);
            let cipher = ChaCha20Poly1305::new(cipher_key);
            let std_nonce = Nonce::from_slice(nonce);

            cipher.encrypt(std_nonce, plaintext.as_bytes())
                .map_err(|e| format!("Gagal mengenkripsi ChaCha20: {}", e))
        }
        _ => {
            key_bytes.zeroize();
            return Err(format!("Panjang nonce tidak valid (harus 12 atau 24 bytes), diterima: {}", nonce.len()));
        }
    };

    key_bytes.zeroize();
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_xchacha20_encrypt_decrypt_roundtrip() {
        let key = [42u8; 32];
        let nonce = [7u8; 24];
        let json_payload = r#"{"type":"call","callerName":"Budi","callType":"video","callId":"call_123"}"#;

        let encrypted = encrypt_push_payload(json_payload, &nonce, &key).expect("Enkripsi harus sukses");
        assert_ne!(encrypted, json_payload.as_bytes());

        let decrypted = decrypt_push_payload(&encrypted, &nonce, &key).expect("Dekripsi harus sukses");
        assert_eq!(decrypted, json_payload);
    }

    #[test]
    fn test_chacha20_std_encrypt_decrypt_roundtrip() {
        let key = [99u8; 32];
        let nonce = [3u8; 12];
        let json_payload = r#"{"type":"sos","senderName":"Siti","lat":-6.2088,"lng":106.8456}"#;

        let encrypted = encrypt_push_payload(json_payload, &nonce, &key).expect("Enkripsi harus sukses");
        let decrypted = decrypt_push_payload(&encrypted, &nonce, &key).expect("Dekripsi harus sukses");
        assert_eq!(decrypted, json_payload);
    }

    #[test]
    fn test_tampered_ciphertext_fails_mac_verification() {
        let key = [42u8; 32];
        let nonce = [7u8; 24];
        let json_payload = r#"{"type":"call","callerName":"Rahasia"}"#;

        let mut encrypted = encrypt_push_payload(json_payload, &nonce, &key).unwrap();
        // Manipulasi 1 byte di ciphertext
        encrypted[0] ^= 0xFF;

        let result = decrypt_push_payload(&encrypted, &nonce, &key);
        assert!(result.is_err(), "Payload termanipulasi wajib ditolak oleh verifikasi MAC Poly1305");
    }

    #[test]
    fn test_wrong_key_fails_decryption() {
        let key = [42u8; 32];
        let wrong_key = [43u8; 32];
        let nonce = [7u8; 24];
        let json_payload = r#"{"type":"call","roomId":"room_abc"}"#;

        let encrypted = encrypt_push_payload(json_payload, &nonce, &key).unwrap();
        let result = decrypt_push_payload(&encrypted, &nonce, &wrong_key);
        assert!(result.is_err(), "Kunci salah wajib ditolak");
    }
}
