import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_model.dart';
import '../services/supabase_service.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(SupabaseService());
});

class TripRepository {
  final SupabaseService _supabaseService;

  TripRepository(this._supabaseService);

  Future<List<UserTrip>> getUserTrips() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('user_trips')
        .select('*, trip_guardians(*, profiles(display_name, username))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => UserTrip.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<UserTrip> createTrip({
    required String title,
    String? originLabel,
    required TripZone destinationZone,
    String? expectedTime,
    int gracePeriodMinutes = 30,
    required List<TripGuardianPermission> guardians,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Pengguna belum masuk');

    final tripData = {
      'user_id': userId,
      'title': title,
      'origin_label': originLabel,
      'destination_label': destinationZone.label,
      'destination_lat': destinationZone.latitude,
      'destination_lng': destinationZone.longitude,
      'radius_meters': destinationZone.radiusMeters,
      'expected_time': expectedTime,
      'grace_period_minutes': gracePeriodMinutes,
      'is_active': true,
    };

    final tripRes = await _supabaseService.client
        .from('user_trips')
        .insert(tripData)
        .select()
        .single();

    final tripId = tripRes['id'] as String;

    if (guardians.isNotEmpty) {
      final guardiansData = guardians.map((g) => {
        'trip_id': tripId,
        'guardian_id': g.guardianId,
        'delay_minutes': g.delayMinutes,
      }).toList();

      await _supabaseService.client
          .from('trip_guardians')
          .insert(guardiansData);
    }

    final fullTrip = await _supabaseService.client
        .from('user_trips')
        .select('*, trip_guardians(*, profiles(display_name, username))')
        .eq('id', tripId)
        .single();

    return UserTrip.fromJson(fullTrip);
  }

  Future<void> toggleTripActive(String tripId, bool isActive) async {
    await _supabaseService.client
        .from('user_trips')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', tripId);
  }

  Future<void> deleteTrip(String tripId) async {
    await _supabaseService.client
        .from('user_trips')
        .delete()
        .eq('id', tripId);
  }
}
