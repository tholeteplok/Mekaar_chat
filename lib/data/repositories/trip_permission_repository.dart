import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_permission_model.dart';
import '../services/supabase_service.dart';
import '../../features/auth/providers/auth_provider.dart';

class TripPermissionRepository {
  final SupabaseService _supabaseService;
  final Logger _log = Logger();

  TripPermissionRepository(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Memulai sesi Hangout baru
  Future<TripPermission> startHangoutSession({
    required String guardianId,
    required String destinationName,
    required DateTime endTime,
    int pingIntervalMinutes = 5,
    bool reminder15mEnabled = true,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User belum login');

    try {
      final response = await _client
          .from('trip_permissions')
          .insert({
            'user_id': userId,
            'guardian_id': guardianId,
            'destination_name': destinationName,
            'start_time': DateTime.now().toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'ping_interval_minutes': pingIntervalMinutes,
            'reminder_15m_enabled': reminder15mEnabled,
            'status': 'active',
          })
          .select()
          .single();

      return TripPermission.fromMap(response);
    } catch (e) {
      _log.e('TripPermissionRepository: startHangoutSession failed: $e');
      rethrow;
    }
  }

  /// Update koordinat ping lokasi secara berkala
  Future<void> updatePingLocation(String sessionId, double lat, double lon) async {
    try {
      await _client.from('trip_permissions').update({
        'last_lat': lat,
        'last_lon': lon,
        'last_ping_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      _log.w('TripPermissionRepository: updatePingLocation failed: $e');
    }
  }

  /// Menghentikan sesi Hangout sepihak oleh anak
  Future<void> cancelHangoutSession(String sessionId) async {
    try {
      await _client.from('trip_permissions').update({
        'status': 'cancelled_by_user',
      }).eq('id', sessionId);
      _log.i('TripPermissionRepository: session $sessionId cancelled by user');
    } catch (e) {
      _log.e('TripPermissionRepository: cancelHangoutSession failed: $e');
      rethrow;
    }
  }

  /// Ambil sesi Hangout aktif milik user
  Future<TripPermission?> getActiveHangoutSession() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('trip_permissions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_time', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .maybeSingle();

      if (response == null) return null;
      return TripPermission.fromMap(response);
    } catch (e) {
      _log.w('TripPermissionRepository: getActiveHangoutSession error: $e');
      return null;
    }
  }

  /// Ambil sesi Hangout aktif di mana user adalah guardian
  Future<List<TripPermission>> getActiveHangoutsForGuardian() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('trip_permissions')
          .select()
          .eq('guardian_id', userId)
          .eq('status', 'active')
          .gte('end_time', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List).map((e) => TripPermission.fromMap(e)).toList();
    } catch (e) {
      _log.w('TripPermissionRepository: getActiveHangoutsForGuardian error: $e');
      return [];
    }
  }
}

final tripPermissionRepositoryProvider = Provider<TripPermissionRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TripPermissionRepository(supabaseService);
});
