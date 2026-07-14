import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

/// AudioService mengelola mic streaming untuk fitur SOS.
/// Menggunakan flutter_webrtc untuk capture audio lokal.
/// Streaming berhenti saat endSOS() dipanggil atau dispose.
class AudioService {
  static final Logger _logger = Logger();

  MediaStream? _micStream;
  bool _isStreaming = false;

  bool get isMicActive => _isStreaming && _micStream != null;

  /// Mulai mic streaming — capture audio dari mikrofon perangkat.
  /// Mengembalikan [true] jika berhasil, [false] jika permission ditolak atau error.
  Future<bool> startMicStreaming() async {
    if (_isStreaming) {
      _logger.w('AudioService: Mic sudah aktif, skip start.');
      return true;
    }

    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

      _micStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isStreaming = true;
      _logger.i('AudioService: Mic streaming DIMULAI — track aktif: ${_micStream!.getAudioTracks().length}');
      return true;
    } catch (e) {
      _logger.e('AudioService: Gagal memulai mic streaming: $e');
      _isStreaming = false;
      _micStream = null;
      return false;
    }
  }

  /// Hentikan mic streaming dan bersihkan resource.
  Future<void> stopMicStreaming() async {
    if (!_isStreaming) return;

    try {
      if (_micStream != null) {
        for (final track in _micStream!.getAudioTracks()) {
          await track.stop();
        }
        await _micStream!.dispose();
        _micStream = null;
      }
      _isStreaming = false;
      _logger.i('AudioService: Mic streaming DIHENTIKAN.');
    } catch (e) {
      _logger.e('AudioService: Error saat menghentikan mic: $e');
      _isStreaming = false;
      _micStream = null;
    }
  }

  /// Toggle mute/unmute tanpa menghentikan stream.
  void setMuted(bool muted) {
    if (_micStream == null) return;
    for (final track in _micStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
    _logger.i('AudioService: Mic ${muted ? "MUTED" : "UNMUTED"}');
  }

  /// Bersihkan semua resource saat service di-dispose.
  Future<void> dispose() async {
    await stopMicStreaming();
  }
}
