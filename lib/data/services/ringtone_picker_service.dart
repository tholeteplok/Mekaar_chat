import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RingtoneType {
  notification,
  ringtone,
  alarm,
}

class RingtonePickResult {
  final String path;
  final String title;
  final String? uri;

  const RingtonePickResult({
    required this.path,
    required this.title,
    this.uri,
  });

  @override
  String toString() => 'RingtonePickResult(title: $title, path: $path, uri: $uri)';
}

class RingtonePickerService {
  static const MethodChannel _channel =
      MethodChannel('com.mekaar.mekaar_chat/ringtone_picker');

  static Future<RingtonePickResult?> pickRingtone({
    RingtoneType type = RingtoneType.notification,
    String? title,
    String? currentUri,
  }) async {
    // Pada Android, gunakan pemilih ringtone bawaan sistem (RingtoneManager)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'pickRingtone',
          {
            'type': type.name,
            'title': title,
            'currentUri': currentUri,
          },
        );

        if (result != null && result['path'] != null) {
          return RingtonePickResult(
            path: result['path'] as String,
            title: result['title'] as String? ?? 'Ringtone Perangkat',
            uri: result['uri'] as String?,
          );
        }
        return null;
      } on PlatformException catch (e) {
        debugPrint('RingtonePickerService: Gagal memanggil native picker ($e), mencoba fallback FilePicker.');
      }
    }

    // Fallback umum (non-Android atau jika native picker error): gunakan FilePicker
    try {
      final fileResult = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (fileResult != null && fileResult.files.single.path != null) {
        final path = fileResult.files.single.path!;
        final name = fileResult.files.single.name;
        return RingtonePickResult(
          path: path,
          title: name,
        );
      }
    } catch (e) {
      debugPrint('RingtonePickerService: Gagal memilih berkas audio: $e');
    }

    return null;
  }
}
