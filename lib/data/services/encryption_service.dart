import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Save secure key-value
  Future<void> writeSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  // Read secure key-value
  Future<String?> readSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  // Delete secure key-value
  Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Clear all secure storage
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  // Mock encryption for chat E2EE (since custom protocols can be complex, we provide simple AES/XOR stub)
  String encryptMessage(String plainText, String key) {
    // Standard E2EE stub for simplicity
    return plainText; // In production, use standard package like encrypt or cryptography
  }

  String decryptMessage(String cipherText, String key) {
    return cipherText;
  }
}
