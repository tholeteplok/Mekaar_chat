import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'e2ee_service.dart';

/// Service for uploading chat media to Supabase Storage.
/// Bucket name: 'chat-media' — must be created in Supabase dashboard (or via migration).
class MediaUploadService {
  final SupabaseClient _client;

  /// Batas ukuran maksimal berkas: 15 MB
  /// Disesuaikan dengan batas kuota penyimpanan (1 GB) dan bandwidth egress (2 GB/bulan) Supabase Free Tier.
  static const int maxFileSizeBytes = 15 * 1024 * 1024;

  MediaUploadService(this._client);

  /// Uploads [file] to chat-media bucket under [roomId] folder.
  /// Returns the public URL of the uploaded file.
  Future<String> uploadChatMedia(File file, String roomId) async {
    final length = await file.length();
    if (length > maxFileSizeBytes) {
      throw Exception('Ukuran file melebihi batas maksimal 15 MB (keterbatasan kuota Supabase gratis).');
    }

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = _extensionFromFileOrMime(file.path, mimeType);
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
    final length = await file.length();
    if (length > maxFileSizeBytes) {
      throw Exception('Ukuran file melebihi batas maksimal 15 MB (keterbatasan kuota Supabase gratis).');
    }
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = _extensionFromFileOrMime(file.path, mimeType);
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

  String _extensionFromFileOrMime(String filePath, String mimeType) {
    final dotIdx = filePath.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < filePath.length - 1) {
      final ext = filePath.substring(dotIdx).toLowerCase();
      if (!ext.contains(' ') && ext.length <= 10) {
        return ext;
      }
    }
    return _extensionFromMime(mimeType);
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
    if (mimeType.contains('pdf')) { return '.pdf'; }
    if (mimeType.contains('word') || mimeType.contains('document')) { return '.docx'; }
    if (mimeType.contains('excel') || mimeType.contains('sheet')) { return '.xlsx'; }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) { return '.pptx'; }
    if (mimeType.contains('text/plain')) { return '.txt'; }
    if (mimeType.contains('csv')) { return '.csv'; }
    if (mimeType.contains('zip')) { return '.zip'; }
    if (mimeType.contains('x-rar')) { return '.rar'; }
    if (mimeType.contains('7z')) { return '.7z'; }
    return '';
  }

  /// Deletes a file from chat-media bucket by its public URL.
  Future<void> deleteMediaByUrl(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      final bucketIdx = pathSegments.indexOf('chat-media');
      if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
        final storagePath = pathSegments.sublist(bucketIdx + 1).join('/');
        await _client.storage.from('chat-media').remove([storagePath]);
      }
    } catch (e) {
      // Log: file orphan di storage jika deletion gagal
      // ignore: avoid_print
      print('[MediaUploadService] deleteMediaByUrl gagal: $e');
    }
  }
}
