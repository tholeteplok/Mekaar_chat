import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nearby_friend_model.dart';

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return NearbyRepository(Supabase.instance.client);
});

class NearbyRepository {
  final SupabaseClient _client;

  NearbyRepository(this._client);

  /// Mengambil preferensi berbagi jarak pengguna saat ini
  Future<NearbyPreferences> getPreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const NearbyPreferences(enabled: false);
    }

    try {
      final response = await _client
          .from('nearby_sharing_prefs')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response == null) {
        return const NearbyPreferences(enabled: false);
      }

      return NearbyPreferences.fromJson(response);
    } catch (_) {
      return const NearbyPreferences(enabled: false);
    }
  }

  /// Memperbarui preferensi berbagi jarak
  Future<NearbyPreferences> updatePreferences({
    required bool enabled,
    String? visibilityMode,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Pengguna belum terotentikasi.');
    }

    final payload = <String, dynamic>{
      'user_id': uid,
      'enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (visibilityMode != null) {
      payload['visibility_mode'] = visibilityMode;
    }

    final response = await _client
        .from('nearby_sharing_prefs')
        .upsert(payload)
        .select()
        .single();

    // Jika dinonaktifkan, hapus ping lokasi seketika (instant revocation)
    if (!enabled) {
      await _client
          .from('nearby_location_pings')
          .delete()
          .eq('user_id', uid)
          .catchError((_) {});
    }

    return NearbyPreferences.fromJson(response);
  }

  /// Memperbarui lokasi device pengguna dan mengambil daftar teman sekitar
  Future<List<NearbyFriendModel>> updateLocationAndFetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      final response = await _client.rpc(
        'get_nearby_friends',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );

      if (response == null || response is! List) {
        return [];
      }

      return response
          .map((item) => NearbyFriendModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Menonaktifkan fitur dan menghapus lokasi
  Future<void> disableNearbySharing() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await updatePreferences(enabled: false);
    } catch (_) {}
  }
}
