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

  /// Khusus dipakai TripMonitorService: hanya trip AKTIF milik pengguna
  /// yang sedang login.
  Future<List<UserTrip>> getActiveTripsForMonitoring() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('user_trips')
        .select('*, trip_guardians(*, profiles(display_name, username))')
        .eq('user_id', userId)
        .eq('is_active', true);

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
    List<int> recurrenceDays = const [],
    List<int>? activeDays,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Pengguna belum masuk');

    final days = recurrenceDays.isNotEmpty
        ? recurrenceDays
        : (activeDays ?? const [1, 2, 3, 4, 5, 6, 7]);

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
      'recurrence_days': days,
      'active_days': days,
      'status': TripStatus.scheduled.name,
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

  /// Ambil satu trip (dipakai TripMonitorService & layar konfirmasi)
  Future<UserTrip?> getTripById(String tripId) async {
    final res = await _supabaseService.client
        .from('user_trips')
        .select('*, trip_guardians(*, profiles(display_name, username))')
        .eq('id', tripId)
        .maybeSingle();
    return res != null ? UserTrip.fromJson(res) : null;
  }

  /// Update status siklus HARI INI
  Future<void> updateTripStatus(
    String tripId,
    TripStatus status, {
    DateTime? snoozedUntil,
  }) async {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    await _supabaseService.client.from('user_trips').update({
      'status': status.name,
      'active_date': todayDateOnly.toIso8601String(),
      'last_triggered_at': today.toIso8601String(),
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil.toIso8601String(),
      if (status != TripStatus.snoozed) 'snoozed_until': null,
    }).eq('id', tripId);
  }

  /// Dipanggil saat pengguna menekan "Ya, Sudah Sampai" secara manual
  Future<void> confirmArrivalManually(String tripId) =>
      updateTripStatus(tripId, TripStatus.arrivedConfirmed);

  /// Dipanggil saat pengguna menekan "Tunda"
  Future<void> snoozeTrip(String tripId, int minutes) => updateTripStatus(
        tripId,
        TripStatus.snoozed,
        snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
      );
}
