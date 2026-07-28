import 'dart:async';
import 'package:logger/logger.dart';
import '../models/message_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../repositories/chat_repository.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class DelayedCheckInService {
  static final Logger _logger = Logger();
  static final Map<String, DateTime> _warnedTrips = {};
  static final Map<String, bool> _alertedTrips = {};

  /// Evaluasi keterlambatan tiba untuk trip yang dijadwalkan
  static Future<void> checkTripDelays({
    required TripRepository tripRepository,
    required ChatRepository chatRepository,
  }) async {
    try {
      final activeTrips = await tripRepository.getUserTrips();
      final now = DateTime.now();

      for (final trip in activeTrips) {
        if (!trip.isActive || trip.expectedTime == null) continue;

        final parts = trip.expectedTime!.split(':');
        if (parts.length < 2) continue;

        final expectedHour = int.tryParse(parts[0]) ?? 0;
        final expectedMinute = int.tryParse(parts[1]) ?? 0;

        final expectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          expectedHour,
          expectedMinute,
        );

        final deadline = expectedDateTime.add(Duration(minutes: trip.gracePeriodMinutes));

        // Jika waktu sekarang melewati deadline + grace period
        if (now.isAfter(deadline)) {
          if (_alertedTrips[trip.id] == true) continue;

          // 1. Tampilkan notifikasi peringatan lokal 5 menit sebelum alert dikirim
          final firstWarn = _warnedTrips[trip.id];
          if (firstWarn == null) {
            _warnedTrips[trip.id] = now;
            await NotificationService.showNormalNotification(
              title: '📍 Konfirmasi Tiba di ${trip.destinationZone.label}',
              body: 'Waktu perkiraan tiba Anda telah lewat ${trip.gracePeriodMinutes} menit. Apakah Anda sudah sampai?',
            );
            _logger.i('Peringatan keterlambatan lokal ditampilkan untuk trip "${trip.title}"');
          } else if (now.difference(firstWarn).inMinutes >= 5) {
            // 2. Jika 5 menit dari peringatan lokal tidak dikonfirmasi, kirim Alert ke Guardian
            _alertedTrips[trip.id] = true;
            await _sendDelayedAlertToGuardians(
              trip: trip,
              chatRepository: chatRepository,
            );
          }
        }
      }
    } catch (e) {
      _logger.w('Gagal mengevaluasi keterlambatan trip: $e');
    }
  }

  static Future<void> _sendDelayedAlertToGuardians({
    required UserTrip trip,
    required ChatRepository chatRepository,
  }) async {
    _logger.w('Mengirimkan Delayed Check-In Alert ke Guardian untuk trip: "${trip.title}"');

    final supabase = SupabaseService().client;
    final currentUserId = SupabaseService().currentUserId;
    if (currentUserId == null) return;

    for (final guardian in trip.guardians) {
      try {
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
            '⚠️ Peringatan Keterlambatan: Belum check-in di ${trip.destinationZone.label} (Melewati batas waktu ${trip.gracePeriodMinutes} menit)',
            type: MessageType.text,
          );
        }
      } catch (e) {
        _logger.w('Gagal mengirim Delayed Alert ke guardian ${guardian.guardianId}: $e');
      }
    }
  }

  /// Batalkan status peringatan jika pengguna mengonfirmasi manual
  static void cancelTripDelayWarning(String tripId) {
    _warnedTrips.remove(tripId);
    _alertedTrips[tripId] = true; // Tandai selesai agar tidak terpicu lagi
  }
}
