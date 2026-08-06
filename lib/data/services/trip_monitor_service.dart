import 'dart:math' as math;
import 'package:logger/logger.dart';
import '../models/message_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../repositories/chat_repository.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Otak terpadu fitur Auto Check-In Rute -- menggantikan GeofenceService &
/// DelayedCheckInService dengan 1 pintu masuk untuk kedua jenis deteksi,
/// urutan prioritas jelas (GPS dulu, baru waktu sebagai fallback),
/// dan status disimpan permanen di kolom `user_trips.status`.
class TripMonitorService {
  static final Logger _logger = Logger();

  /// Berapa lama menunggu respons pengguna atas notifikasi konfirmasi
  /// kedatangan sebelum eskalasi ke Guardian.
  static const Duration confirmationTimeout = Duration(minutes: 5);

  static Future<void> evaluate({
    required TripRepository tripRepository,
    required ChatRepository chatRepository,
    double? currentLat,
    double? currentLng,
  }) async {
    List<UserTrip> trips;
    try {
      trips = await tripRepository.getActiveTripsForMonitoring();
    } catch (e) {
      _logger.w('TripMonitorService: gagal ambil daftar trip aktif: $e');
      return;
    }

    final now = DateTime.now();

    for (final trip in trips) {
      if (!trip.isScheduledForToday) continue;

      final status = trip.effectiveStatus;

      // Sudah "selesai" untuk hari ini -- tidak perlu dievaluasi lagi
      // sampai hari berganti (effectiveStatus otomatis reset besok).
      if (status == TripStatus.arrivedAuto ||
          status == TripStatus.arrivedConfirmed ||
          status == TripStatus.delayedAlerted) {
        continue;
      }

      if (status == TripStatus.snoozed &&
          trip.snoozedUntil != null &&
          now.isBefore(trip.snoozedUntil!)) {
        continue; // masih dalam masa tunda, skip dulu
      }

      try {
        // --- 1. GPS selalu dicek lebih dulu bila lokasi tersedia. ---
        if (currentLat != null && currentLng != null) {
          final dest = trip.destinationZone;
          final distance = calculateDistanceMeters(
            currentLat,
            currentLng,
            dest.latitude,
            dest.longitude,
          );
          if (distance <= dest.radiusMeters) {
            await tripRepository.updateTripStatus(trip.id, TripStatus.arrivedAuto);
            await _sendToGuardians(
              trip: trip,
              chatRepository: chatRepository,
              text: '📍 Auto Check-In: Telah sampai di ${dest.label}',
            );
            _logger.i('Auto check-in (GPS) untuk "${trip.title}"');
            continue;
          }
        }

        // --- 2. Fallback: evaluasi berbasis waktu. ---
        if (trip.expectedTime == null) continue;
        final deadline = _parseDeadline(trip, now);
        if (deadline == null || now.isBefore(deadline)) continue;

        if (status == TripStatus.scheduled || status == TripStatus.snoozed) {
          // Baru pertama kali (atau baru selesai masa tunda) lewat deadline.
          await tripRepository.updateTripStatus(trip.id, TripStatus.delayedWarned);
          await NotificationService.showTripConfirmationNotification(
            tripId: trip.id,
            destinationLabel: trip.destinationZone.label,
            graceMinutes: trip.gracePeriodMinutes,
          );
          _logger.i('Konfirmasi kedatangan ditampilkan untuk "${trip.title}"');
        } else if (status == TripStatus.delayedWarned) {
          final warnedAt = trip.lastTriggeredAt;
          if (warnedAt != null &&
              now.difference(warnedAt) >= confirmationTimeout) {
            await tripRepository.updateTripStatus(trip.id, TripStatus.delayedAlerted);
            await _sendToGuardians(
              trip: trip,
              chatRepository: chatRepository,
              text: '⚠️ Peringatan Keterlambatan: Belum check-in di '
                  '${trip.destinationZone.label} (melewati batas waktu '
                  '${trip.gracePeriodMinutes} menit)',
            );
            _logger.w('Eskalasi ke Guardian untuk "${trip.title}" (tidak direspons)');
          }
        }
      } catch (e) {
        _logger.w('Gagal evaluasi trip "${trip.title}": $e');
      }
    }
  }

  static DateTime? _parseDeadline(UserTrip trip, DateTime now) {
    final parts = trip.expectedTime!.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final expected = DateTime(now.year, now.month, now.day, hour, minute);
    return expected.add(Duration(minutes: trip.gracePeriodMinutes));
  }

  static Future<void> _sendToGuardians({
    required UserTrip trip,
    required ChatRepository chatRepository,
    required String text,
  }) async {
    final supabase = SupabaseService().client;
    final currentUserId = SupabaseService().currentUserId;
    if (currentUserId == null) return;

    for (final guardian in trip.guardians) {
      try {
        final roomRes = await supabase
            .from('room_participants')
            .select('room_id')
            .eq('profile_id', currentUserId);

        final myRoomIds =
            (roomRes as List<dynamic>).map((r) => r['room_id'] as String).toList();
        if (myRoomIds.isEmpty) continue;

        final matchRes = await supabase
            .from('room_participants')
            .select('room_id')
            .eq('profile_id', guardian.guardianId)
            .filter('room_id', 'in', myRoomIds)
            .maybeSingle();

        if (matchRes != null) {
          final roomId = matchRes['room_id'] as String;
          await chatRepository.sendMessage(roomId, text, type: MessageType.text);
        }
      } catch (e) {
        _logger.w('Gagal kirim pesan trip ke guardian ${guardian.guardianId}: $e');
      }
    }
  }

  /// Rumus Haversine (meter)
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
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
}
