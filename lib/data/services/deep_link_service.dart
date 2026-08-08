import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:logger/logger.dart';
import 'supabase_service.dart';

/// Menangkap deep link mekaarchat://reset-password yang dikirim Supabase
/// lewat email reset password, lalu menukarnya jadi sesi pemulihan lewat
/// Supabase SDK. Navigasi ke layar set-password-baru TIDAK dilakukan di
/// sini -- itu didengarkan lewat Supabase.instance.client.auth.
/// onAuthStateChange (event passwordRecovery) di main.dart, karena
/// itulah sinyal resmi "link ini valid & sesi pemulihan aktif", bukan
/// sekadar "link ini ke-tap".
class DeepLinkService {
  static final Logger _logger = Logger();
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;

  static Future<void> initialize() async {
    try {
      // Tangani cold-start: app dibuka PERTAMA KALI lewat link ini.
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (e) {
      _logger.w('DeepLinkService: gagal ambil initial link: $e');
    }

    // Tangani link yang datang SAAT app sudah berjalan (warm/background).
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => _logger.w('DeepLinkService: stream error: $e'),
    );
  }

  static Future<void> _handleUri(Uri uri) async {
    _logger.i('DeepLinkService: menerima URI: $uri');
    if (uri.scheme != 'mekaarchat' || uri.host != 'reset-password') {
      return; // bukan link yang kita tangani, abaikan
    }
    try {
      // Menukar kode/token di URL jadi sesi Supabase aktif.
      await SupabaseService().client.auth.getSessionFromUrl(uri);
    } catch (e) {
      _logger.w('DeepLinkService: gagal tukar sesi dari URL: $e');
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
