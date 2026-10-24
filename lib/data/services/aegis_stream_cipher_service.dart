import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import '../../src/rust/api/stream_cipher.dart' as rust_stream;
import 'aegis_memory_guard_service.dart';
import 'aegis_shredder_service.dart';

/// Layanan enkripsi dan dekripsi berkas media secara streaming (Aegis Streaming Media Vault).
///
/// Memproses berkas audio/video besar dalam potongan terotentikasi 64KB (XChaCha20-Poly1305)
/// langsung ke disk storage, mengeliminasi spike alokasi RAM Dart dan frame-drops.
class AegisStreamCipherService {
  AegisStreamCipherService._();
  static final AegisStreamCipherService instance = AegisStreamCipherService._();

  static final Logger _logger = Logger();
  static final Xchacha20 _fallbackCipher = Xchacha20.poly1305Aead();

  static const List<int> _magicHeader = [0x4D, 0x4B, 0x53, 0x54]; // 'MKST'
  static const int _version = 1;
  static const int _chunkSize = 64 * 1024; // 64 KB

  /// Mengenkripsi file dari `srcPath` ke `dstPath` menggunakan kunci di `keySlotId`
  Future<BigInt> encryptFileStream({
    required String srcPath,
    required String dstPath,
    required BigInt keySlotId,
  }) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      throw FileSystemException('File sumber tidak ditemukan', srcPath);
    }

    await AegisShredderService.ensureInitialized();

    try {
      return await rust_stream.encryptFileStream(
        srcPath: srcPath,
        dstPath: dstPath,
        keySlotId: keySlotId,
      );
    } catch (e) {
      _logger.d('StreamCipher native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      return _encryptFileStreamDartFallback(
        srcFile: srcFile,
        dstFile: File(dstPath),
        keySlotId: keySlotId,
      );
    }
  }

  /// Mendekripsi file terenkripsi dari `srcPath` ke `dstPath` menggunakan kunci di `keySlotId`
  Future<BigInt> decryptFileStream({
    required String srcPath,
    required String dstPath,
    required BigInt keySlotId,
  }) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      throw FileSystemException('File sumber tidak ditemukan', srcPath);
    }

    await AegisShredderService.ensureInitialized();

    try {
      return await rust_stream.decryptFileStream(
        srcPath: srcPath,
        dstPath: dstPath,
        keySlotId: keySlotId,
      );
    } catch (e) {
      _logger.d('StreamCipher native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      return _decryptFileStreamDartFallback(
        srcFile: srcFile,
        dstFile: File(dstPath),
        keySlotId: keySlotId,
      );
    }
  }

  Future<BigInt> _encryptFileStreamDartFallback({
    required File srcFile,
    required File dstFile,
    required BigInt keySlotId,
  }) async {
    final rawKey = AegisMemoryGuardService.instance.getFallbackKey(keySlotId);
    if (rawKey == null) {
      throw StateError('Kunci untuk slot #$keySlotId tidak ditemukan di MemoryGuard');
    }

    final secretKey = SecretKey(rawKey);
    final srcRaf = await srcFile.open(mode: FileMode.read);
    final dstRaf = await dstFile.open(mode: FileMode.write);

    try {
      // 1. Buat random 16-byte nonce prefix
      final random = Random.secure();
      final noncePrefix = Uint8List(16);
      for (int i = 0; i < 16; i++) {
        noncePrefix[i] = random.nextInt(256);
      }

      // 2. Tulis Header: MKST (4B) + Version (1B) + Nonce Prefix (16B)
      await dstRaf.writeFrom(_magicHeader);
      await dstRaf.writeByte(_version);
      await dstRaf.writeFrom(noncePrefix);

      final srcLen = await srcFile.length();
      int totalRead = 0;
      int chunkIndex = 0;
      int totalWritten = 4 + 1 + 16;

      final buffer = Uint8List(_chunkSize);

      while (true) {
        final read = await srcRaf.readInto(buffer, 0, _chunkSize);
        totalRead += read;
        final isLast = totalRead >= srcLen;

        // Nonce 24B: prefix (16B) + chunkIndex BE (8B)
        final nonceBytes = Uint8List(24);
        nonceBytes.setRange(0, 16, noncePrefix);
        final bd = ByteData.view(nonceBytes.buffer, 16, 8);
        bd.setUint64(0, chunkIndex, Endian.big);

        // Associated Data (AD): chunkIndex BE (8B) + isLast (1B)
        final ad = Uint8List(9);
        final adBd = ByteData.view(ad.buffer, 0, 8);
        adBd.setUint64(0, chunkIndex, Endian.big);
        ad[8] = isLast ? 1 : 0;

        final chunkData = Uint8List.view(buffer.buffer, 0, read);
        final secretBox = await _fallbackCipher.encrypt(
          chunkData,
          secretKey: secretKey,
          nonce: nonceBytes,
          aad: ad,
        );

        final encryptedBytes = secretBox.concatenation(nonce: false, mac: true);
        final chunkLenBytes = Uint8List(4);
        ByteData.view(chunkLenBytes.buffer).setUint32(0, encryptedBytes.length, Endian.big);

        await dstRaf.writeFrom(chunkLenBytes);
        await dstRaf.writeByte(ad[8]);
        await dstRaf.writeFrom(encryptedBytes);

        totalWritten += 4 + 1 + encryptedBytes.length;
        chunkIndex++;

        if (isLast) break;
      }

      await dstRaf.flush();
      return BigInt.from(totalWritten);
    } finally {
      await srcRaf.close();
      await dstRaf.close();
    }
  }

  Future<BigInt> _decryptFileStreamDartFallback({
    required File srcFile,
    required File dstFile,
    required BigInt keySlotId,
  }) async {
    final rawKey = AegisMemoryGuardService.instance.getFallbackKey(keySlotId);
    if (rawKey == null) {
      throw StateError('Kunci untuk slot #$keySlotId tidak ditemukan di MemoryGuard');
    }

    final secretKey = SecretKey(rawKey);
    final srcRaf = await srcFile.open(mode: FileMode.read);
    final dstRaf = await dstFile.open(mode: FileMode.write);

    try {
      // 1. Validasi Magic Header (4B)
      final magic = await srcRaf.read(4);
      if (magic.length < 4 ||
          magic[0] != _magicHeader[0] ||
          magic[1] != _magicHeader[1] ||
          magic[2] != _magicHeader[2] ||
          magic[3] != _magicHeader[3]) {
        throw const FormatException('Magic header berkas bukan MKST');
      }

      final ver = await srcRaf.readByte();
      if (ver != _version) {
        throw FormatException('Versi stream cipher tidak didukung: $ver');
      }

      final noncePrefix = await srcRaf.read(16);
      int chunkIndex = 0;
      int totalDecrypted = 0;

      while (true) {
        final lenBytes = await srcRaf.read(4);
        if (lenBytes.isEmpty) break; // EOF
        if (lenBytes.length < 4) {
          throw const FormatException('Header chunk terpotong');
        }

        final chunkDataLen = ByteData.view(lenBytes.buffer).getUint32(0, Endian.big);
        final isLast = (await srcRaf.readByte()) == 1;

        final encryptedChunk = await srcRaf.read(chunkDataLen);
        if (encryptedChunk.length < chunkDataLen) {
          throw const FormatException('Payload chunk terpotong');
        }

        final nonceBytes = Uint8List(24);
        nonceBytes.setRange(0, 16, noncePrefix);
        final bd = ByteData.view(nonceBytes.buffer, 16, 8);
        bd.setUint64(0, chunkIndex, Endian.big);

        final ad = Uint8List(9);
        final adBd = ByteData.view(ad.buffer, 0, 8);
        adBd.setUint64(0, chunkIndex, Endian.big);
        ad[8] = isLast ? 1 : 0;

        // Ekstrak ciphertext & 16-byte MAC tag dari concatenation
        const macLen = 16;
        final cipherLen = chunkDataLen - macLen;
        final cipherText = encryptedChunk.sublist(0, cipherLen);
        final mac = Mac(encryptedChunk.sublist(cipherLen));

        final secretBox = SecretBox(
          cipherText,
          nonce: nonceBytes,
          mac: mac,
        );

        final decryptedBytes = await _fallbackCipher.decrypt(
          secretBox,
          secretKey: secretKey,
          aad: ad,
        );

        await dstRaf.writeFrom(decryptedBytes);
        totalDecrypted += decryptedBytes.length;
        chunkIndex++;

        if (isLast) break;
      }

      await dstRaf.flush();
      return BigInt.from(totalDecrypted);
    } finally {
      await srcRaf.close();
      await dstRaf.close();
    }
  }
}
