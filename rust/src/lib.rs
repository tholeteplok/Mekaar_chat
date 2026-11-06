pub mod api;
mod frb_generated;

use jni::objects::{JByteArray, JClass};
use jni::sys::jstring;
use jni::JNIEnv;

/// JNI export yang dipanggil langsung oleh Native Android Kotlin (AegisNativeBridge.kt)
/// tanpa menginisialisasi Dart VM atau Flutter Engine.
#[no_mangle]
pub extern "system" fn Java_com_mekaar_mekaar_1chat_AegisNativeBridge_decryptPayload<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
    j_ciphertext: JByteArray<'local>,
    j_nonce: JByteArray<'local>,
    j_key: JByteArray<'local>,
) -> jstring {
    let ciphertext = match env.convert_byte_array(&j_ciphertext) {
        Ok(bytes) => bytes,
        Err(_) => return std::ptr::null_mut(),
    };

    let nonce = match env.convert_byte_array(&j_nonce) {
        Ok(bytes) => bytes,
        Err(_) => return std::ptr::null_mut(),
    };

    let key = match env.convert_byte_array(&j_key) {
        Ok(bytes) => bytes,
        Err(_) => return std::ptr::null_mut(),
    };

    match api::push_decryptor::decrypt_push_payload(&ciphertext, &nonce, &key) {
        Ok(decrypted_json) => match env.new_string(decrypted_json) {
            Ok(j_str) => j_str.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(e) => {
            log::warn!("AegisNativeBridge: Dekripsi JNI gagal: {}", e);
            std::ptr::null_mut()
        }
    }
}
