import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';
import 'e2ee_service.dart';

/// Service untuk menangani pengunduhan, dekripsi E2EE, ekspor ke folder
/// publik 'Download/Mekaar/', dan peluncuran viewer dokumen eksternal.
class FileExportService {
  static const MethodChannel _installerChannel =
      MethodChannel('com.mekaar.mekaar_chat/installer');

  /// Mendekripsi dan mengunduh berkas pesan ke cache lokal (jika belum ada).
  static Future<File?> resolveOrDownloadFile(Message message) async {
    final mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return null;

    final meta = message.fileMeta;
    final fileName = meta?.fileName ?? 'dokumen';
    final keyB64 = meta?.keyB64 ?? '';

    // Cache file path
    final tempDir = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final cachedFile = File('${tempDir.path}/mekaar_file_${message.id}_$safeFileName');

    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return cachedFile;
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final request = await client.getUrl(Uri.parse(mediaUrl));
      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;

      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      if (keyB64.isNotEmpty) {
        final decryptedBytes = await E2eeService.instance.decryptMedia(bytes, keyB64);
        await cachedFile.writeAsBytes(decryptedBytes);
      } else {
        await cachedFile.writeAsBytes(bytes);
      }

      return cachedFile;
    } catch (_) {
      return null;
    }
  }

  /// Mengekspor berkas yang telah didekripsi ke folder publik Download/Mekaar/
  static Future<String?> exportToMekaarDownloads({
    required File file,
    required String fileName,
    String? mimeType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    if (Platform.isAndroid) {
      try {
        final result = await _installerChannel.invokeMethod<String>(
          'exportFileToMekaarDownloads',
          {
            'filePath': file.path,
            'fileName': safeName,
            'mimeType': mimeType,
          },
        );
        return result;
      } catch (_) {
        return null;
      }
    } else {
      // Platform lain (Windows/Linux/iOS/macOS)
      try {
        Directory? baseDir;
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          baseDir = await getDownloadsDirectory();
        }
        baseDir ??= await getApplicationDocumentsDirectory();

        final mekaarDir = Directory('${baseDir.path}/Mekaar');
        if (!await mekaarDir.exists()) {
          await mekaarDir.create(recursive: true);
        }

        final targetFile = File('${mekaarDir.path}/$safeName');
        await file.copy(targetFile.path);
        return targetFile.path;
      } catch (_) {
        return null;
      }
    }
  }

  /// Membuka berkas dengan penampil dokumen bawaan sistem operasi.
  static Future<bool> openFileWithChooser({
    required File file,
    String? mimeType,
  }) async {
    if (Platform.isAndroid) {
      try {
        final result = await _installerChannel.invokeMethod<bool>(
          'openFileWithChooser',
          {
            'filePath': file.path,
            'mimeType': mimeType,
          },
        );
        return result ?? false;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', [file.path]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [file.path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
