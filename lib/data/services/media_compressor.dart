import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

class MediaCompressor {
  MediaCompressor._();

  static const int maxImageDimension = 1920;
  static const int imageQuality = 70;
  static const int pngToJpegThreshold = 500 * 1024; // 500KB
  static const int voiceBitrateThreshold = 1024 * 1024; // 1MB
  static const int maxVideoDurationSec = 180; // 3 menit

  static Future<File> compressImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final originalSize = await file.length();

    final bool forceJpeg;
    int quality = imageQuality;
    if (ext == 'png' && originalSize > pngToJpegThreshold) {
      forceJpeg = true;
      quality = 65;
    } else {
      forceJpeg = false;
    }

    final format = forceJpeg ? CompressFormat.jpeg : CompressFormat.jpeg;

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.absolute.path}_compressed.jpg',
      format: format,
      quality: quality,
      minWidth: maxImageDimension,
      minHeight: maxImageDimension,
    );

    if (result == null) return file;

    final compressedFile = File(result.path);
    final compressedSize = await compressedFile.length();
    if (compressedSize >= originalSize) {
      await compressedFile.delete();
      return file;
    }

    await file.delete();
    return compressedFile;
  }

  static Future<File> compressVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.Res640x480Quality,
      deleteOrigin: false,
    );

    if (info?.file == null) return file;

    final compressedSize = await info!.file!.length();
    final originalSize = await file.length();

    if (compressedSize >= originalSize) {
      await info.file!.delete();
      return file;
    }

    await file.delete();
    return info.file!;
  }

  static Future<File> compressAudio(File file) async {
    final originalSize = await file.length();
    if (originalSize <= voiceBitrateThreshold) return file;

    // Voice notes: use flutter_image_compress won't work for audio.
    // For m4a/aac files we return original since re-encoding requires
    // a full audio processing pipeline. The record package already
    // encodes at 128kbps AAC which is reasonable.
    // Future enhancement: integrate ffmpeg_kit_flutter for audio transcode.
    return file;
  }

  static Future<File> compress(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final imageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    final videoExts = {'mp4', 'mov', 'avi', 'mkv', '3gp'};
    final audioExts = {'m4a', 'aac', 'mp3', 'wav'};

    if (imageExts.contains(ext)) {
      return compressImage(file);
    }
    if (videoExts.contains(ext)) {
      return compressVideo(file);
    }
    if (audioExts.contains(ext)) {
      return compressAudio(file);
    }
    return file;
  }

  static String? estimateCompression(File original, File compressed) {
    final orig = original.lengthSync();
    final comp = compressed.lengthSync();
    if (comp >= orig) return null;
    final pct = ((1 - comp / orig) * 100).round();
    return '$pct% lebih kecil';
  }
}
