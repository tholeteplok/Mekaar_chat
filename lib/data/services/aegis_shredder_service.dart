import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../../src/rust/api/shredder.dart' as rust_shredder;
import '../../src/rust/frb_generated.dart';

/// Layanan sanitasi berkas tingkat forensik (Aegis Forensic Shredder).
///
/// Menggunakan Rust Core (`mekaar_aegis_core`) untuk mengeksekusi penimpaan fisik CSPRNG
/// multi-pass disertai pemanggilan `sync_all` hardware flash controller,
/// dengan dukungan fail-safe Pure-Dart fallback jika binary native tidak dimuat.
class AegisShredderService {
  AegisShredderService._();
  static final AegisShredderService instance = AegisShredderService._();

  static final Logger _logger = Logger();
  static bool _rustInitialized = false;

  /// Memastikan RustLib terinisialisasi
  static Future<void> ensureInitialized() async {
    if (_rustInitialized) return;
    try {
      await RustLib.init();
      _rustInitialized = true;
    } catch (e) {
      // Fallback ke Pure-Dart jika di lingkungan test runner atau binary belum ada
      _rustInitialized = false;
      _logger.d('RustLib native core tidak aktif, menggunakan Pure-Dart Fallback: $e');
    }
  }

  /// Memusnahkan file secara fisik dari chip penyimpanan (DoD / NIST Sanitization).
  ///
  /// Menimpa byte file dengan data acak hardware `OsRng`, melakukan zero-fill,
  /// truncate 0 byte, melakukan hardware flash sync, lalu menghapus entri file.
  Future<bool> shredFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;

    await ensureInitialized();

    if (_rustInitialized) {
      try {
        return await rust_shredder.shredFile(path: path);
      } catch (e) {
        _logger.w('Gagal mengeksekusi Rust shred_file, fallback ke Dart: $e');
      }
    }

    return _shredFileDartFallback(file);
  }

  /// Memusnahkan seluruh berkas di dalam suatu direktori secara rekursif (mis. cache rekaman audio/gambar).
  Future<int> shredDirectoryContents(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;

    await ensureInitialized();

    if (_rustInitialized) {
      try {
        return await rust_shredder.shredDirectoryContents(dirPath: dirPath);
      } catch (e) {
        _logger.w('Gagal mengeksekusi Rust shred_directory_contents, fallback ke Dart: $e');
      }
    }

    return _shredDirectoryContentsDartFallback(dir);
  }

  Future<bool> _shredFileDartFallback(File file) async {
    try {
      final len = await file.length();
      if (len > 0) {
        final random = Random.secure();
        final raf = await file.open(mode: FileMode.write);
        const chunkSize = 64 * 1024;
        final buffer = Uint8List(chunkSize);

        // Pass 1: Random overwrite
        await raf.setPosition(0);
        int written = 0;
        while (written < len) {
          final toWrite = (len - written > chunkSize) ? chunkSize : (len - written);
          for (int i = 0; i < toWrite; i++) {
            buffer[i] = random.nextInt(256);
          }
          await raf.writeFrom(buffer, 0, toWrite);
          written += toWrite;
        }
        await raf.flush();

        // Pass 2: Zero-fill
        await raf.setPosition(0);
        buffer.fillRange(0, chunkSize, 0);
        written = 0;
        while (written < len) {
          final toWrite = (len - written > chunkSize) ? chunkSize : (len - written);
          await raf.writeFrom(buffer, 0, toWrite);
          written += toWrite;
        }
        await raf.flush();

        // Pass 3: Truncate
        await raf.truncate(0);
        await raf.flush();
        await raf.close();
      }

      // Pass 4: Unlink
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      _logger.e('Gagal melakukan fallback shredding pada ${file.path}: $e');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return false;
    }
  }

  Future<int> _shredDirectoryContentsDartFallback(Directory dir) async {
    int count = 0;
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          if (await _shredFileDartFallback(entity)) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      _logger.w('Gagal melakukan shredding direktori ${dir.path}: $e');
      return count;
    }
  }
}
