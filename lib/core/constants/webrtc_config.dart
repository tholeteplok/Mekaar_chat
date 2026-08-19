import 'package:flutter/foundation.dart';

/// WebRtcConfig — Sumber tunggal konfigurasi ICE & TURN untuk WebRTC.
/// Digunakan oleh seluruh layanan WebRTC di aplikasi (Panggilan 1:1 dan Emergency).
class WebRtcConfig {
  WebRtcConfig._();

  static const String _turnUrl = String.fromEnvironment('TURN_URL');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  /// Membangun konfigurasi ICE servers terpusat.
  /// Pada mode produksi, set --dart-define=TURN_URL=... (+ TURN_USERNAME, TURN_CREDENTIAL).
  static Map<String, dynamic> buildIceConfiguration() {
    final iceServers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ],
      },
    ];

    if (_turnUrl.isNotEmpty) {
      iceServers.add({
        'urls': _turnUrl,
        'username': _turnUsername,
        'credential': _turnCredential,
      });
    } else if (kDebugMode) {
      debugPrint(
        '⚠️ WebRtcConfig: TURN_URL tidak diset, memakai relay publik '
        'openrelay.metered.ca (DEV ONLY). Set --dart-define=TURN_URL '
        '(+ TURN_USERNAME/TURN_CREDENTIAL) sebelum build produksi.',
      );
      iceServers.addAll(const [
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ]);
    }

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
  }
}
