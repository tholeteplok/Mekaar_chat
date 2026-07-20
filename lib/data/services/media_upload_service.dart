import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'e2ee_service.dart';

/// Service for uploading chat media to Supabase Storage.
/// Bucket name: 'chat-media' — must be created in Supabase dashboard (or via migration).
class MediaUploadService {
  final SupabaseClient _client;

  MediaUploadService(this._client);

  /// Uploads [file] to chat-media bucket under [roomId] folder.
  /// Returns the public URL of the uploaded file.
  Future<String> uploadChatMedia(File file, String roomId) async {
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = _extensionFromMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = _client.auth.currentUser?.id ?? 'anon';
    final storagePath = '$roomId/${userId}_$timestamp$ext';

    final bytes = await file.readAsBytes();
    await _client.storage.from('chat-media').uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );

    return _client.storage.from('chat-media').getPublicUrl(storagePath);
  }

  /// Uploads and encrypts [file] before storing it in Supabase Storage.
  /// Returns the public URL and the Base64-encoded secret key used for encryption.
  Future<({String url, String keyB64})> uploadEncryptedChatMedia(File file, String roomId) async {
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = _extensionFromMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = _client.auth.currentUser?.id ?? 'anon';
    final storagePath = '$roomId/${userId}_$timestamp$ext';

    // Baca byte asli file, lalu enkripsi menggunakan E2EE
    final rawBytes = await file.readAsBytes();
    final encryptedResult = await E2eeService.instance.encryptMedia(rawBytes);

    await _client.storage.from('chat-media').uploadBinary(
      storagePath,
      Uint8List.fromList(encryptedResult.bytes),
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );

    final publicUrl = _client.storage.from('chat-media').getPublicUrl(storagePath);
    return (url: publicUrl, keyB64: encryptedResult.keyB64);
  }

  /// Returns a signed URL valid for 7 days (for private buckets).
  Future<String> getSignedUrl(
    String storagePath, {
    int expiresInSeconds = 604800,
  }) async {
    return await _client.storage
        .from('chat-media')
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  String _extensionFromMime(String mimeType) {
    if (mimeType.startsWith('image/jpeg')) { return '.jpg'; }
    if (mimeType.startsWith('image/png')) { return '.png'; }
    if (mimeType.startsWith('image/gif')) { return '.gif'; }
    if (mimeType.startsWith('image/webp')) { return '.webp'; }
    if (mimeType.startsWith('video/mp4')) { return '.mp4'; }
    if (mimeType.startsWith('audio/mpeg')) { return '.mp3'; }
    if (mimeType.startsWith('audio/aac')) { return '.aac'; }
    if (mimeType.startsWith('audio/wav')) { return '.wav'; }
    if (mimeType.startsWith('audio/m4a') ||
        mimeType.startsWith('audio/x-m4a')) { return '.m4a'; }
    return '';
  }
}
