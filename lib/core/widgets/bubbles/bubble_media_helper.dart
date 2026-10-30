import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/e2ee_service.dart';
import '../../constants/typography.dart';

/// Helper terpusat untuk me-resolve TextStyle pada bubble chat yang menjamin
/// penggunaan font aktif (dari preferensi pengguna atau tema bubble khusus)
/// melalui runtime loader GoogleFonts.
TextStyle resolveBubbleTextStyle({
  required Color color,
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w400,
  double height = 1.4,
  String? fontFamily,
  FontStyle? fontStyle,
  TextDecoration? decoration,
}) {
  final activeFont = (fontFamily != null && fontFamily.isNotEmpty)
      ? fontFamily
      : MekaarTypography.fontFamily;
  try {
    return GoogleFonts.getFont(
      activeFont,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  } catch (_) {
    return TextStyle(
      fontFamily: activeFont,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }
}

/// Helper publik untuk mendapatkan atau mendekripsi file media pesan
Future<File?> getOrDecryptMedia({
  required String messageId,
  required String? url,
  required bool isEncrypted,
  required String fileKeyB64,
}) => _getOrDecryptMedia(
  messageId: messageId,
  url: url,
  isEncrypted: isEncrypted,
  fileKeyB64: fileKeyB64,
);

/// In-memory cache untuk berkas media yang sudah selesai diunduh/didekripsi
/// Menghindari I/O disk berulang dan menghilangkan kedipan (flickering) saat widget di-rebuild.
final Map<String, File> _decryptedFileMemoryCache = <String, File>{};
final Map<String, Future<File?>> _inFlightMediaFutures =
    <String, Future<File?>>{};

/// Direktori temporer yang di-cache di memori agar pengecekan disk dapat berjalan sinkron (0ms)
String? _cachedTempDirPath;

/// Inisialisasi awal direktori temporer (dapat dipanggil saat startup atau pre-warming)
Future<void> prewarmMediaCacheDir() async {
  try {
    final dir = await getTemporaryDirectory();
    _cachedTempDirPath = dir.path;
  } catch (_) {}
}

/// Mendaftarkan berkas lokal (misalnya media yang baru dikirim oleh pengguna)
/// ke memory cache seketika agar tidak terjadi kedipan / spinner pada pengirim.
void registerLocalMedia(String messageId, File file, {String? url}) {
  if (file.existsSync()) {
    _decryptedFileMemoryCache[messageId] = file;
    if (_cachedTempDirPath != null) {
      try {
        final ext = (url != null && url.isNotEmpty)
            ? (Uri.tryParse(url)?.pathSegments.isNotEmpty == true
                  ? Uri.tryParse(url)!.pathSegments.last.split('.').last
                  : file.path.split('.').last)
            : file.path.split('.').last;
        final targetPath = '$_cachedTempDirPath/decrypted_$messageId.$ext';
        if (file.path != targetPath) {
          final targetFile = File(targetPath);
          if (!targetFile.existsSync()) {
            file.copy(targetPath).catchError((_) => file);
          }
        }
      } catch (_) {}
    }
  }
}

/// Parser payload media cerdas: mengekstrak fileKeyB64 dan caption.
/// Kompatibel 100% dengan pesan E2EE JSON baru maupun pesan lawas plain text / raw key.
({String fileKeyB64, String caption}) parseMediaPayload(Message message) {
  final content = message.content.trim();
  if (content.startsWith('{') && content.endsWith('}')) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return (
          fileKeyB64: decoded['key'] as String? ?? '',
          caption: decoded['caption'] as String? ?? '',
        );
      }
    } catch (_) {}
  }
  // Fallback: pesan legacy
  if (message.isEncrypted) {
    return (fileKeyB64: message.content, caption: '');
  } else {
    return (fileKeyB64: '', caption: message.content);
  }
}

/// Mendapatkan file media dari RAM memory cache atau disk cache lokal secara sinkron (0ms).
/// Menghilangkan kedipan (flicker) layout saat layar chat baru dibuka.
File? getDecryptedFromMemory(String messageId, [String? url]) {
  // 1. Cek memory cache tercepat di RAM
  final cached = _decryptedFileMemoryCache[messageId];
  if (cached != null && cached.existsSync()) {
    return cached;
  }

  // 2. Jika path temp sudah diketahui, lakukan pengecekan sinkron ke disk
  if (_cachedTempDirPath != null) {
    try {
      String? ext;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          ext = uri.pathSegments.last.split('.').last;
        }
      }

      if (ext != null && ext.isNotEmpty) {
        final directCheck = File(
          '$_cachedTempDirPath/decrypted_$messageId.$ext',
        );
        if (directCheck.existsSync() && directCheck.lengthSync() > 0) {
          _decryptedFileMemoryCache[messageId] = directCheck;
          return directCheck;
        }
      }

      // Cek kemungkinan ekstensi umum jika url tidak memuat ekstensi pasti
      for (final candidateExt in const [
        'jpg',
        'png',
        'jpeg',
        'webp',
        'mp4',
        'bin',
      ]) {
        final candidate = File(
          '$_cachedTempDirPath/decrypted_$messageId.$candidateExt',
        );
        if (candidate.existsSync() && candidate.lengthSync() > 0) {
          _decryptedFileMemoryCache[messageId] = candidate;
          return candidate;
        }
      }
    } catch (_) {}
  } else {
    // Picu prewarm di latar belakang untuk query berikutnya
    prewarmMediaCacheDir();
  }

  return null;
}

@visibleForTesting
void setDecryptedTempDirPathForTesting(String? path) {
  _cachedTempDirPath = path;
}

@visibleForTesting
void setDecryptedMemoryCacheForTesting(String messageId, File file) {
  _decryptedFileMemoryCache[messageId] = file;
}

@visibleForTesting
void clearDecryptedMemoryCacheForTesting() {
  _decryptedFileMemoryCache.clear();
}

// Helper function to download, decrypt, and cache E2EE media locally with memory caching.
Future<File?> _getOrDecryptMedia({
  required String messageId,
  required String? url,
  required bool isEncrypted,
  required String fileKeyB64,
}) async {
  if (url == null || url.isEmpty) return null;

  // 1. Cek memory cache tercepat (0ms delay)
  final inMemory = getDecryptedFromMemory(messageId, url);
  if (inMemory != null && inMemory.existsSync()) {
    return inMemory;
  }

  // 2. Cegah request berulang yang sedang berjalan (in-flight deduplication)
  if (_inFlightMediaFutures.containsKey(messageId)) {
    return _inFlightMediaFutures[messageId]!;
  }

  final future = _doGetOrDecryptMedia(
    messageId: messageId,
    url: url,
    isEncrypted: isEncrypted,
    fileKeyB64: fileKeyB64,
  );
  _inFlightMediaFutures[messageId] = future;

  try {
    final result = await future;
    if (result != null) {
      _decryptedFileMemoryCache[messageId] = result;
    }
    return result;
  } finally {
    _inFlightMediaFutures.remove(messageId);
  }
}

Future<File?> _doGetOrDecryptMedia({
  required String messageId,
  required String? url,
  required bool isEncrypted,
  required String fileKeyB64,
}) async {
  if (url == null || url.isEmpty) return null;

  try {
    // Ekstrak effective key jika fileKeyB64 berupa JSON payload
    String effectiveKey = fileKeyB64.trim();
    if (effectiveKey.startsWith('{') && effectiveKey.endsWith('}')) {
      try {
        final decoded = jsonDecode(effectiveKey);
        if (decoded is Map<String, dynamic> && decoded['key'] != null) {
          effectiveKey = decoded['key'] as String;
        }
      } catch (_) {}
    }

    final tempDir = await getTemporaryDirectory();
    _cachedTempDirPath = tempDir.path;
    final uri = Uri.parse(url);
    final ext = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.split('.').last
        : 'bin';
    final cachedFile = File('${tempDir.path}/decrypted_$messageId.$ext');

    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return cachedFile;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) return null;

    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

    if (isEncrypted && effectiveKey.isNotEmpty) {
      final decryptedBytes = await E2eeService.instance.decryptMedia(
        bytes,
        effectiveKey,
      );
      await cachedFile.writeAsBytes(decryptedBytes);
    } else {
      await cachedFile.writeAsBytes(bytes);
    }

    return cachedFile;
  } catch (_) {
    return null;
  }
}
