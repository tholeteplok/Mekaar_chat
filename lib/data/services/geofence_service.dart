import 'dart:async';
import 'dart:math' as math;
import 'package:logger/logger.dart';
import '../models/message_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../repositories/chat_repository.dart';
import '../services/supabase_service.dart';

class GeofenceService {
  static final Logger _logger = Logger();
  static final Map<String, bool> _triggeredTrips = {};

  /// Hitung jarak 2 koordinat dengan rumus Haversine (dalam meter)
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Radius bumi dalam meter
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;

  /// Evaluasi lokasi perangkat terhadap seluruh trip aktif pengguna
  static Future<void> checkCurrentLocationAgainstTrips({
    required double currentLat,
    required double currentLng,
    required TripRepository tripRepository,
    required ChatRepository chatRepository,
  }) async {
    try {
      final activeTrips = await tripRepository.getUserTrips();

      for (final trip in activeTrips) {
        if (!trip.isActive) continue;

        final dest = trip.destinationZone;
        final distance = calculateDistanceMeters(
          currentLat,
          currentLng,
          dest.latitude,
          dest.longitude,
        );

        _logger.i('Geofence check "${trip.title}": jarak ${distance.toStringAsFixed(1)}m / radius ${dest.radiusMeters}m');

        // Jika berada di dalam radius geofence dan belum dipicu untuk trip ini
        if (distance <= dest.radiusMeters) {
          if (_triggeredTrips[trip.id] != true) {
            _triggeredTrips[trip.id] = true;
            await _triggerAutoCheckIn(
              trip: trip,
              chatRepository: chatRepository,
            );
          }
        } else {
          // Reset status jika user telah berada jauh di luar zone
          if (distance > dest.radiusMeters * 2) {
            _triggeredTrips[trip.id] = false;
          }
        }
      }
    } catch (e) {
      _logger.w('Gagal mengevaluasi geofence: $e');
    }
  }

  static Future<void> _triggerAutoCheckIn({
    required UserTrip trip,
    required ChatRepository chatRepository,
  }) async {
    _logger.i('Auto Check-In dipicu untuk trip: "${trip.title}" ke ${trip.destinationZone.label}');

    final supabase = SupabaseService().client;
    final currentUserId = SupabaseService().currentUserId;
    if (currentUserId == null) return;

    // Kirim pesan terenkripsi ke setiap Guardian yang terdaftar
    for (final guardian in trip.guardians) {
      try {
        // Cari room DM antara user dan guardian
        final roomRes = await supabase
            .from('room_participants')
            .select('room_id')
            .eq('profile_id', currentUserId);

        final myRoomIds = (roomRes as List<dynamic>)
            .map((r) => r['room_id'] as String)
            .toList();

        if (myRoomIds.isEmpty) continue;

        final matchRes = await supabase
            .from('room_participants')
            .select('room_id')
            .eq('profile_id', guardian.guardianId)
            .filter('room_id', 'in', myRoomIds)
            .maybeSingle();

        if (matchRes != null) {
          final roomId = matchRes['room_id'] as String;
          await chatRepository.sendMessage(
            roomId,
            '📍 Auto Check-In: Telah sampai di ${trip.destinationZone.label}',
            type: MessageType.text,
          );
          _logger.i('Auto Check-In terkirim ke guardian ${guardian.guardianId} di room $roomId');
        }
      } catch (e) {
        _logger.w('Gagal mengirim Auto Check-In ke guardian ${guardian.guardianId}: $e');
      }
    }
  }
}
