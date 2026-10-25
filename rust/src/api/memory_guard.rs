use argon2::{Algorithm, Argon2, Params, Version};
use lazy_static::lazy_static;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use zeroize::{Zeroize, Zeroizing};

static NEXT_SLOT_ID: AtomicU64 = AtomicU64::new(1);

lazy_static! {
    /// Registry memori global yang diisolasi di heap native Rust.
    /// Kunci dibungkus dalam Zeroizing agar langsung di-zero-fill saat dihapus atau di-drop.
    static ref KEY_REGISTRY: Mutex<HashMap<u64, Zeroizing<[u8; 32]>>> = Mutex::new(HashMap::new());
}

/// Menyimpan raw key 32-byte (256-bit) ke dalam slot memori terisolasi di Rust.
/// Menghasilkan slot_id numerik yang dapat digunakan oleh Dart tanpa membocorkan kunci ke heap Dart GC.
pub fn store_secure_key(mut raw_key: Vec<u8>) -> Result<u64, String> {
    if raw_key.len() != 32 {
        raw_key.zeroize();
        return Err(format!(
            "Panjang kunci tidak valid: diharapkan 32 byte (256-bit), diterima {} byte",
            raw_key.len()
        ));
    }

    let mut key_arr = [0u8; 32];
    key_arr.copy_from_slice(&raw_key);
    raw_key.zeroize(); // Segera zeroize salinan input vector

    let slot_id = NEXT_SLOT_ID.fetch_add(1, Ordering::SeqCst);
    let mut registry = KEY_REGISTRY
        .lock()
        .map_err(|e| format!("Gagal mengunci registry kunci: {}", e))?;

    registry.insert(slot_id, Zeroizing::new(key_arr));
    Ok(slot_id)
}

/// Menurunkan kunci 256-bit (32 byte) dari PIN/Passcode menggunakan Argon2id (Memory-Hard KDF).
/// Kunci hasil derivasi langsung disimpan di `KEY_REGISTRY` (Zeroizing), dan slot_id numerik dikembalikan.
/// Byte mentah passcode dan salt langsung di-zeroize dari memori RAM.
pub fn derive_vault_key(mut passcode: String, mut salt: Vec<u8>) -> Result<u64, String> {
    if passcode.is_empty() {
        return Err("Passcode tidak boleh kosong".to_string());
    }
    if salt.len() < 8 {
        return Err("Salt minimal wajib 8 byte".to_string());
    }

    // OWASP recommendation: Memory 64MB (65536 KiB), Time cost: 3, Parallelism: 4, Output: 32 bytes
    let params = Params::new(65536, 3, 4, Some(32))
        .map_err(|e| format!("Konfigurasi parameter Argon2 tidak valid: {}", e))?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    let mut derived_key = [0u8; 32];
    argon2
        .hash_password_into(passcode.as_bytes(), &salt, &mut derived_key)
        .map_err(|e| format!("Gagal melakukan derivasi Argon2id: {}", e))?;

    // Zeroize inputs
    passcode.zeroize();
    salt.zeroize();

    let slot_id = NEXT_SLOT_ID.fetch_add(1, Ordering::SeqCst);
    let mut registry = KEY_REGISTRY
        .lock()
        .map_err(|e| format!("Gagal mengunci registry kunci: {}", e))?;

    registry.insert(slot_id, Zeroizing::new(derived_key));
    derived_key.zeroize();

    Ok(slot_id)
}

/// Memeriksa apakah suatu slot kunci masih aktif di memori RAM
pub fn has_secure_key(slot_id: u64) -> bool {
    if let Ok(registry) = KEY_REGISTRY.lock() {
        registry.contains_key(&slot_id)
    } else {
        false
    }
}

/// Memusnahkan kunci di slot tertentu dari memori RAM seketika (Zeroize)
pub fn zeroize_key(slot_id: u64) -> bool {
    if let Ok(mut registry) = KEY_REGISTRY.lock() {
        // .remove() mengembalikan nilai Zeroizing yang akan di-drop dan otomatis di-zero-fill
        registry.remove(&slot_id).is_some()
    } else {
        false
    }
}

/// Menghancurkan seluruh kunci rahasia di memori RAM (Panic Lockdown / Logout)
pub fn zeroize_all_keys() -> u32 {
    if let Ok(mut registry) = KEY_REGISTRY.lock() {
        let count = registry.len() as u32;
        registry.clear(); // Memanggil drop pada seluruh elemen Zeroizing
        count
    } else {
        0
    }
}

/// Helper internal untuk modul Rust lain (misalnya stream cipher) mengakses referensi kunci secara aman
pub(crate) fn with_key<F, R>(slot_id: u64, f: F) -> Result<R, String>
where
    F: FnOnce(&[u8; 32]) -> Result<R, String>,
{
    let registry = KEY_REGISTRY
        .lock()
        .map_err(|e| format!("Gagal mengakses registry kunci: {}", e))?;

    if let Some(key) = registry.get(&slot_id) {
        f(&*key)
    } else {
        Err(format!("Slot kunci #{} tidak ditemukan atau sudah di-zeroize dari RAM", slot_id))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex as TestMutex;

    static TEST_LOCK: TestMutex<()> = TestMutex::new(());

    #[test]
    fn test_store_and_zeroize_key() {
        let _guard = TEST_LOCK.lock().unwrap();
        let dummy_key = vec![0x42u8; 32];
        let slot_id = store_secure_key(dummy_key).unwrap();

        assert!(has_secure_key(slot_id));

        // Akses internal valid
        let read_result = with_key(slot_id, |k| Ok(k[0]));
        assert_eq!(read_result.unwrap(), 0x42);

        // Zeroize kunci
        let deleted = zeroize_key(slot_id);
        assert!(deleted);
        assert!(!has_secure_key(slot_id));

        // Akses setelah zeroize wajib gagal
        let failed_result = with_key(slot_id, |k| Ok(k[0]));
        assert!(failed_result.is_err());
    }

    #[test]
    fn test_derive_vault_key_argon2id() {
        let _guard = TEST_LOCK.lock().unwrap();
        let pin = "123456".to_string();
        let salt = vec![0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0];
        let slot_id = derive_vault_key(pin, salt).unwrap();

        assert!(has_secure_key(slot_id));

        // Pastikan kunci yang dihasilkan dapat dibaca melalui with_key
        let check_res = with_key(slot_id, |k| {
            // Memastikan kunci bukan sekadar nol
            let is_all_zero = k.iter().all(|&b| b == 0);
            assert!(!is_all_zero);
            Ok(())
        });
        assert!(check_res.is_ok());

        assert!(zeroize_key(slot_id));
        assert!(!has_secure_key(slot_id));
    }

    #[test]
    fn test_invalid_key_length() {
        let _guard = TEST_LOCK.lock().unwrap();
        let short_key = vec![0x01u8; 16]; // Hanya 16 byte
        let res = store_secure_key(short_key);
        assert!(res.is_err());
    }

    #[test]
    fn test_zeroize_all_keys() {
        let _guard = TEST_LOCK.lock().unwrap();
        let k1 = store_secure_key(vec![1u8; 32]).unwrap();
        let k2 = store_secure_key(vec![2u8; 32]).unwrap();

        assert!(has_secure_key(k1));
        assert!(has_secure_key(k2));

        let wiped = zeroize_all_keys();
        assert!(wiped >= 2);

        assert!(!has_secure_key(k1));
        assert!(!has_secure_key(k2));
    }
}
