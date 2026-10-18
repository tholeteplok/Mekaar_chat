import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Service untuk mengontrol native Wakelock (FLAG_KEEP_SCREEN_ON).
/// Mencegah layar mati / timeout kunci layar saat panggilan suara atau video
/// sedang aktif.
class WakelockService {
  static final Logger _logger = Logger();
  static const MethodChannel _channel =
      MethodChannel('com.mekaar.mekaar_chat/wakelock');

  static bool _isEnabled = false;

  /// Status apakah wakelock sedang aktif.
  static bool get isEnabled => _isEnabled;

  /// Mengaktifkan wakelock agar layar tetap menyala dan tidak terkena timeout kunci layar.
  static Future<void> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final success = await _channel.invokeMethod<bool>('enable');
      if (success == true) {
        _isEnabled = true;
        _logger.d('WakelockService: Layar dikunci tetap menyala (FLAG_KEEP_SCREEN_ON aktif)');
      }
    } catch (e) {
      _logger.w('WakelockService: Gagal mengaktifkan wakelock: $e');
    }
  }

  /// Menonaktifkan wakelock agar layar kembali mengikuti durasi timeout sistem normal.
  static Future<void> disable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final success = await _channel.invokeMethod<bool>('disable');
      if (success == true) {
        _isEnabled = false;
        _logger.d('WakelockService: Layar kembali normal (FLAG_KEEP_SCREEN_ON dilepas)');
      }
    } catch (e) {
      _logger.w('WakelockService: Gagal menonaktifkan wakelock: $e');
    }
  }
}
