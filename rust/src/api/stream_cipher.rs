use crate::api::memory_guard;
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{Key, XChaCha20Poly1305, XNonce};
use rand::rngs::OsRng;
use rand::RngCore;
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};

const MAGIC_HEADER: &[u8; 4] = b"MKST";
const VERSION: u8 = 1;
const CHUNK_SIZE: usize = 64 * 1024; // 64 KB per payload block
const TAG_SIZE: usize = 16; // Poly1305 128-bit MAC tag
const HEADER_SIZE: usize = 4 + 1 + 16; // Magic (4) + Version (1) + Nonce Prefix (16)

/// Mengenkripsi berkas sumber ke berkas tujuan menggunakan XChaCha20-Poly1305 streaming chunks (64KB).
/// Kunci diambil secara aman dari slot memori terisolasi (`key_slot_id`).
pub fn encrypt_file_stream(
    src_path: String,
    dst_path: String,
    key_slot_id: u64,
) -> Result<u64, String> {
    memory_guard::with_key(key_slot_id, |key_bytes| {
        let key = Key::from_slice(key_bytes);
        let cipher = XChaCha20Poly1305::new(key);

        let mut src_file = File::open(&src_path)
            .map_err(|e| format!("Gagal membuka file sumber '{}': {}", src_path, e))?;

        let mut dst_file = OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(&dst_path)
            .map_err(|e| format!("Gagal membuat file tujuan '{}': {}", dst_path, e))?;

        // 1. Buat random 16-byte nonce prefix
        let mut nonce_prefix = [0u8; 16];
        OsRng.fill_bytes(&mut nonce_prefix);

        // 2. Tulis File Header: Magic (4B) + Version (1B) + Nonce Prefix (16B)
        dst_file
            .write_all(MAGIC_HEADER)
            .map_err(|e| format!("Gagal menulis magic header: {}", e))?;
        dst_file
            .write_all(&[VERSION])
            .map_err(|e| format!("Gagal menulis header versi: {}", e))?;
        dst_file
            .write_all(&nonce_prefix)
            .map_err(|e| format!("Gagal menulis nonce prefix: {}", e))?;

        let mut chunk_buffer = vec![0u8; CHUNK_SIZE];
        let mut chunk_index = 0u64;
        let mut total_written = HEADER_SIZE as u64;

        let src_len = src_file
            .metadata()
            .map_err(|e| format!("Gagal membaca metadata sumber: {}", e))?
            .len();

        let mut bytes_read_total = 0u64;

        loop {
            let bytes_read = src_file
                .read(&mut chunk_buffer)
                .map_err(|e| format!("Gagal membaca chunk sumber: {}", e))?;

            bytes_read_total += bytes_read as u64;
            let is_last = bytes_read_total >= src_len;

            // Bentuk 24-byte XNonce: [nonce_prefix (16B), chunk_index (8B big-endian)]
            let mut nonce_bytes = [0u8; 24];
            nonce_bytes[..16].copy_from_slice(&nonce_prefix);
            nonce_bytes[16..].copy_from_slice(&chunk_index.to_be_bytes());
            let nonce = XNonce::from_slice(&nonce_bytes);

            // Associated Data (AD): chunk_index (8B) + is_last (1B) untuk anti-reorder & anti-truncation
            let mut ad = [0u8; 9];
            ad[..8].copy_from_slice(&chunk_index.to_be_bytes());
            ad[8] = if is_last { 1 } else { 0 };

            let payload = Payload {
                msg: &chunk_buffer[..bytes_read],
                aad: &ad,
            };

            let encrypted_chunk = cipher
                .encrypt(nonce, payload)
                .map_err(|e| format!("Gagal mengenkripsi chunk #{}: {}", chunk_index, e))?;

            // Tulis metadata chunk: len (u32 BE) + is_last (1B) + ciphertext + tag
            let chunk_data_len = encrypted_chunk.len() as u32;
            dst_file
                .write_all(&chunk_data_len.to_be_bytes())
                .map_err(|e| format!("Gagal menulis chunk len: {}", e))?;
            dst_file
                .write_all(&[ad[8]])
                .map_err(|e| format!("Gagal menulis chunk is_last: {}", e))?;
            dst_file
                .write_all(&encrypted_chunk)
                .map_err(|e| format!("Gagal menulis ciphertext chunk: {}", e))?;

            total_written += 4 + 1 + encrypted_chunk.len() as u64;
            chunk_index += 1;

            if is_last {
                break;
            }
        }

        dst_file
            .sync_all()
            .map_err(|e| format!("Gagal sync physical flash: {}", e))?;

        Ok(total_written)
    })
}

/// Mendekripsi berkas terenkripsi MEKAAR stream ke berkas tujuan asli.
pub fn decrypt_file_stream(
    src_path: String,
    dst_path: String,
    key_slot_id: u64,
) -> Result<u64, String> {
    memory_guard::with_key(key_slot_id, |key_bytes| {
        let key = Key::from_slice(key_bytes);
        let cipher = XChaCha20Poly1305::new(key);

        let mut src_file = File::open(&src_path)
            .map_err(|e| format!("Gagal membuka file sumber terenkripsi '{}': {}", src_path, e))?;

        let mut dst_file = OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(&dst_path)
            .map_err(|e| format!("Gagal membuat file tujuan plaintext '{}': {}", dst_path, e))?;

        // 1. Baca dan validasi Header
        let mut header_magic = [0u8; 4];
        src_file
            .read_exact(&mut header_magic)
            .map_err(|e| format!("Gagal membaca magic header: {}", e))?;

        if &header_magic != MAGIC_HEADER {
            return Err("Format berkas tidak valid: Magic header bukan MKST".to_string());
        }

        let mut version_byte = [0u8; 1];
        src_file
            .read_exact(&mut version_byte)
            .map_err(|e| format!("Gagal membaca versi header: {}", e))?;

        if version_byte[0] != VERSION {
            return Err(format!("Versi format stream tidak didukung: {}", version_byte[0]));
        }

        let mut nonce_prefix = [0u8; 16];
        src_file
            .read_exact(&mut nonce_prefix)
            .map_err(|e| format!("Gagal membaca nonce prefix: {}", e))?;

        let mut chunk_index = 0u64;
        let mut total_decrypted = 0u64;

        loop {
            // Baca chunk_data_len (4 bytes)
            let mut len_buf = [0u8; 4];
            match src_file.read_exact(&mut len_buf) {
                Ok(_) => {}
                Err(ref e) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                    // Selesai jika file berakhir tepat di batas chunk
                    break;
                }
                Err(e) => return Err(format!("Gagal membaca ukuran chunk #{}: {}", chunk_index, e)),
            }

            let chunk_data_len = u32::from_be_bytes(len_buf) as usize;
            if chunk_data_len < TAG_SIZE || chunk_data_len > CHUNK_SIZE + TAG_SIZE {
                return Err(format!(
                    "Ukuran chunk #{} di luar batas wajar ({} bytes)",
                    chunk_index, chunk_data_len
                ));
            }

            // Baca is_last flag (1 byte)
            let mut is_last_buf = [0u8; 1];
            src_file
                .read_exact(&mut is_last_buf)
                .map_err(|e| format!("Gagal membaca is_last flag #{}: {}", chunk_index, e))?;

            // Baca ciphertext chunk
            let mut encrypted_chunk = vec![0u8; chunk_data_len];
            src_file
                .read_exact(&mut encrypted_chunk)
                .map_err(|e| format!("Gagal membaca payload chunk #{}: {}", chunk_index, e))?;

            // Rekonstruksi XNonce
            let mut nonce_bytes = [0u8; 24];
            nonce_bytes[..16].copy_from_slice(&nonce_prefix);
            nonce_bytes[16..].copy_from_slice(&chunk_index.to_be_bytes());
            let nonce = XNonce::from_slice(&nonce_bytes);

            // Rekonstruksi Associated Data (AD)
            let mut ad = [0u8; 9];
            ad[..8].copy_from_slice(&chunk_index.to_be_bytes());
            ad[8] = is_last_buf[0];

            let payload = Payload {
                msg: &encrypted_chunk,
                aad: &ad,
            };

            let decrypted_chunk = cipher.decrypt(nonce, payload).map_err(|_| {
                format!(
                    "Verifikasi integritas MAC gagal pada chunk #{} (File rusak atau kunci salah)",
                    chunk_index
                )
            })?;

            dst_file
                .write_all(&decrypted_chunk)
                .map_err(|e| format!("Gagal menulis plaintext chunk #{}: {}", chunk_index, e))?;

            total_decrypted += decrypted_chunk.len() as u64;
            chunk_index += 1;

            if is_last_buf[0] == 1 {
                break;
            }
        }

        dst_file
            .sync_all()
            .map_err(|e| format!("Gagal sync plaintext: {}", e))?;

        Ok(total_decrypted)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stream_encrypt_and_decrypt_small_file() {
        let temp_dir = std::env::temp_dir().join("test_stream_small");
        let _ = std::fs::remove_dir_all(&temp_dir);
        std::fs::create_dir_all(&temp_dir).unwrap();

        let raw_file = temp_dir.join("origin.txt");
        let enc_file = temp_dir.join("origin.txt.enc");
        let dec_file = temp_dir.join("decrypted.txt");

        let original_data = b"Pesan rahasia personal safety MEKAAR streaming 12345";
        std::fs::write(&raw_file, original_data).unwrap();

        let key_id = memory_guard::store_secure_key(vec![0x77u8; 32]).unwrap();

        // Enkripsi
        let written = encrypt_file_stream(
            raw_file.to_string_lossy().to_string(),
            enc_file.to_string_lossy().to_string(),
            key_id,
        )
        .unwrap();
        assert!(written > original_data.len() as u64);

        // Dekripsi
        let decrypted_len = decrypt_file_stream(
            enc_file.to_string_lossy().to_string(),
            dec_file.to_string_lossy().to_string(),
            key_id,
        )
        .unwrap();
        assert_eq!(decrypted_len, original_data.len() as u64);

        let recovered_data = std::fs::read(&dec_file).unwrap();
        assert_eq!(recovered_data, original_data);

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_stream_encrypt_multi_chunk_256kb() {
        let temp_dir = std::env::temp_dir().join("test_stream_256k");
        let _ = std::fs::remove_dir_all(&temp_dir);
        std::fs::create_dir_all(&temp_dir).unwrap();

        let raw_file = temp_dir.join("payload_256k.bin");
        let enc_file = temp_dir.join("payload.enc");
        let dec_file = temp_dir.join("payload.dec");

        let mut large_payload = vec![0u8; 256 * 1024]; // 256 KB = 4 chunks
        for (i, b) in large_payload.iter_mut().enumerate() {
            *b = (i % 251) as u8;
        }
        std::fs::write(&raw_file, &large_payload).unwrap();

        let key_id = memory_guard::store_secure_key(vec![0x33u8; 32]).unwrap();

        encrypt_file_stream(
            raw_file.to_string_lossy().to_string(),
            enc_file.to_string_lossy().to_string(),
            key_id,
        )
        .unwrap();

        decrypt_file_stream(
            enc_file.to_string_lossy().to_string(),
            dec_file.to_string_lossy().to_string(),
            key_id,
        )
        .unwrap();

        let recovered = std::fs::read(&dec_file).unwrap();
        assert_eq!(recovered, large_payload);

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_stream_tamper_detection() {
        let temp_dir = std::env::temp_dir().join("test_stream_tamper");
        let _ = std::fs::remove_dir_all(&temp_dir);
        std::fs::create_dir_all(&temp_dir).unwrap();

        let raw_file = temp_dir.join("original.bin");
        let enc_file = temp_dir.join("original.enc");
        let dec_file = temp_dir.join("original.dec");

        std::fs::write(&raw_file, b"Data sensitif yang akan ditamper").unwrap();
        let key_id = memory_guard::store_secure_key(vec![0x55u8; 32]).unwrap();

        encrypt_file_stream(
            raw_file.to_string_lossy().to_string(),
            enc_file.to_string_lossy().to_string(),
            key_id,
        )
        .unwrap();

        // Manipulasi 1 byte ciphertext di tengah file
        let mut enc_bytes = std::fs::read(&enc_file).unwrap();
        let target_idx = enc_bytes.len() - 5;
        enc_bytes[target_idx] ^= 0xFF; // Flip bit
        std::fs::write(&enc_file, enc_bytes).unwrap();

        // Dekripsi wajib gagal karena MAC tag tidak cocok
        let result = decrypt_file_stream(
            enc_file.to_string_lossy().to_string(),
            dec_file.to_string_lossy().to_string(),
            key_id,
        );
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("integritas MAC gagal"));

        let _ = std::fs::remove_dir_all(&temp_dir);
    }
}
