use crate::api::memory_guard;
use base64::prelude::BASE64_STANDARD;
use base64::Engine;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use rand::RngCore;

/// Pasangan kunci darurat SOS
pub struct SosKeyPairResult {
    /// ID slot memori terisolasi tempat private seed 32-byte disimpan (Zeroize RAM)
    pub key_slot_id: u64,
    /// Public key Ed25519 dalam format Base64 (untuk didistribusikan ke Guardian)
    pub public_key_b64: String,
}

/// Menghasilkan pasangan kunci Ed25519 baru untuk pengirim SOS.
/// Private key otomatis diamankan di dalam Aegis Memory Guard.
pub fn generate_sos_keypair() -> Result<SosKeyPairResult, String> {
    let mut seed = [0u8; 32];
    OsRng.fill_bytes(&mut seed);

    let signing_key = SigningKey::from_bytes(&seed);
    let verifying_key = signing_key.verifying_key();
    let public_key_b64 = BASE64_STANDARD.encode(verifying_key.as_bytes());

    let key_slot_id = memory_guard::store_secure_key(seed.to_vec())?;

    Ok(SosKeyPairResult {
        key_slot_id,
        public_key_b64,
    })
}

/// Menandatangani paket data darurat kanonikal secara kriptografis menggunakan Ed25519.
/// Kunci rahasia diambil dari slot memori terisolasi (`key_slot_id`).
pub fn sign_sos_packet(canonical_payload: String, key_slot_id: u64) -> Result<String, String> {
    memory_guard::with_key(key_slot_id, |seed_bytes| {
        let signing_key = SigningKey::from_bytes(seed_bytes);
        let signature = signing_key.sign(canonical_payload.as_bytes());
        Ok(BASE64_STANDARD.encode(signature.to_bytes()))
    })
}

/// Memverifikasi tanda tangan digital Ed25519 pada paket darurat yang diterima Guardian.
/// Mencegah serangan spoofing server atau manipulasi koordinat oleh penyerang.
pub fn verify_sos_packet(
    canonical_payload: String,
    signature_b64: String,
    public_key_b64: String,
) -> Result<bool, String> {
    let pubkey_bytes = BASE64_STANDARD
        .decode(&public_key_b64)
        .map_err(|e| format!("Public key bukan Base64 valid: {}", e))?;

    if pubkey_bytes.len() != 32 {
        return Err(format!(
            "Ukuran public key Ed25519 tidak valid: diharapkan 32 byte, diterima {}",
            pubkey_bytes.len()
        ));
    }

    let mut pubkey_arr = [0u8; 32];
    pubkey_arr.copy_from_slice(&pubkey_bytes);

    let verifying_key = VerifyingKey::from_bytes(&pubkey_arr)
        .map_err(|e| format!("Format public key Ed25519 tidak valid: {}", e))?;

    let sig_bytes = BASE64_STANDARD
        .decode(&signature_b64)
        .map_err(|e| format!("Signature bukan Base64 valid: {}", e))?;

    if sig_bytes.len() != 64 {
        return Err(format!(
            "Ukuran signature Ed25519 tidak valid: diharapkan 64 byte, diterima {}",
            sig_bytes.len()
        ));
    }

    let mut sig_arr = [0u8; 64];
    sig_arr.copy_from_slice(&sig_bytes);
    let signature = Signature::from_bytes(&sig_arr);

    match verifying_key.verify(canonical_payload.as_bytes(), &signature) {
        Ok(_) => Ok(true),
        Err(_) => Ok(false),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sos_signature_full_flow() {
        let keypair = generate_sos_keypair().unwrap();
        assert!(keypair.key_slot_id > 0);
        assert!(!keypair.public_key_b64.is_empty());

        let payload = "MEKAAR_SOS_V1:user_001:2026-10-24T21:00:00Z:-6.200000:106.816666:panic";

        // Tandatangani paket darurat
        let signature_b64 = sign_sos_packet(payload.to_string(), keypair.key_slot_id).unwrap();
        assert!(!signature_b64.is_empty());

        // Verifikasi tanda tangan sukses
        let is_valid = verify_sos_packet(
            payload.to_string(),
            signature_b64.clone(),
            keypair.public_key_b64.clone(),
        )
        .unwrap();
        assert!(is_valid);

        // Verifikasi gagal jika koordinat dipalsukan oleh penyerang
        let tampered_payload = "MEKAAR_SOS_V1:user_001:2026-10-24T21:00:00Z:-7.550000:110.816666:panic";
        let is_tampered_valid = verify_sos_packet(
            tampered_payload.to_string(),
            signature_b64,
            keypair.public_key_b64,
        )
        .unwrap();
        assert!(!is_tampered_valid);
    }
}
