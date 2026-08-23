import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Hasil satu saran pencarian lokasi dari Nominatim.
class GeocodingResult {
  final String label;
  final double latitude;
  final double longitude;

  const GeocodingResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  LatLng get location => LatLng(latitude, longitude);
}

/// Klien geocoding Nominatim (OpenStreetMap).
///
/// Catatan kepatuhan (usage policy Nominatim):
/// - Wajib header User-Agent yang mengidentifikasi aplikasi.
/// - Maksimal 1 permintaan/detik — pemanggil WAJIB melakukan debounce
///   di sisi UI (lihat `LocationPickerScreen`, debounce 400ms).
/// - Instance publik tidak didesain untuk traffic produksi tinggi;
///   bila traffic besar, migrasi ke self-hosted/berbayar.
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'com.mekaar.app';

  final http.Client _client;

  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  /// Cari lokasi berdasarkan query teks.
  /// Dibatasi Indonesia (`countrycodes=id`) dan berbahasa Indonesia
  /// (`accept-language=id`) sesuai kebutuhan produk.
  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '0',
      'countrycodes': 'id',
      'accept-language': 'id',
    });

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) {
            final map = item as Map<String, dynamic>;
            final lat = double.tryParse(map['lat'] as String? ?? '');
            final lon = double.tryParse(map['lon'] as String? ?? '');
            if (lat == null || lon == null) return null;
            return GeocodingResult(
              label: (map['display_name'] as String? ?? '').trim(),
              latitude: lat,
              longitude: lon,
            );
          })
          .whereType<GeocodingResult>()
          .toList();
    } catch (_) {
      // Gagal jaringan / timeout / rate-limit: kembalikan kosong,
      // UI cukup menampilkan "tidak ada hasil".
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
