/// WebRtcConfig — Sumber tunggal konfigurasi ICE & TURN untuk WebRTC.
/// Digunakan oleh seluruh layanan WebRTC di aplikasi (Panggilan 1:1 dan Emergency).
class WebRtcConfig {
  WebRtcConfig._();

  static const String _turnUrl = String.fromEnvironment('TURN_URL');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  /// Membangun konfigurasi ICE servers terpusat.
  /// Jika [relayOnly] bernilai true, hanya jalur TURN relay yang diizinkan
  /// guna mencegah kebocoran alamat IP publik/lokal ke peer (Anti-IP Leak).
  /// Pada mode produksi, set --dart-define=TURN_URL=... (+ TURN_USERNAME, TURN_CREDENTIAL).
  static Map<String, dynamic> buildIceConfiguration({bool relayOnly = false}) {
    final iceServers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
          'stun:stun.cloudflare.com:3478',
        ],
      },
    ];

    if (_turnUrl.isNotEmpty) {
      iceServers.add({
        'urls': _turnUrl,
        'username': _turnUsername,
        'credential': _turnCredential,
      });
    }

    final config = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    if (relayOnly) {
      config['iceTransportPolicy'] = 'relay';
    }

    return config;
  }
}
