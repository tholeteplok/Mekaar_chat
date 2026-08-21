import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import '../models/device_lost_model.dart';
import '../repositories/device_lost_repository.dart';
import '../services/alarm_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/navigation/app_navigator.dart';

/// Handler untuk mengeksekusi remote command yang diterima via FCM data message.
///
/// Mendukung tipe perintah:
/// - `alarm`: Membunyikan sirine SOS di perangkat ini
/// - `stop_alarm`: Menghentikan sirine
/// - `lock`: Mengunci layar perangkat ini dengan pesan khusus (Device Lost Lock)
/// - `locate`: Mengirim koordinat GPS perangkat ini kembali ke server
class DeviceCommandHandler {
  static final Logger _logger = Logger();

  /// Eksekusi command berdasarkan data payload dari FCM / Realtime.
  static Future<void> handle(Map<String, dynamic> data) async {
    final commandId = data['commandId'] as String?;
    final commandType = data['commandType'] as String?;
    final payloadRaw = data['payload'];

    Map<String, dynamic> payload = {};
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (payloadRaw is Map<String, dynamic>) {
      payload = payloadRaw;
    }

    _logger.i('DeviceCommandHandler: Menerima command $commandType (id=$commandId)');

    try {
      switch (commandType) {
        case 'alarm':
          await AlarmService.playSOSAlarm();
          break;

        case 'stop_alarm':
          await AlarmService.stopAlarm();
          break;

        case 'lock':
          final lockMessage = payload['lockMessage'] as String? ??
              'Ponsel ini dilaporkan hilang. Harap hubungi kontak pemulihan.';
          final recoveryContact = payload['recoveryContact'] as String?;

          final repo = DeviceLostRepository(SupabaseService());
          await repo.setDeviceLostState(DeviceLostState(
            isLocked: true,
            lockMessage: lockMessage,
            recoveryContact: recoveryContact,
            lockedAt: DateTime.now(),
          ));

          // Jika app sedang aktif di foreground, langsung arahkan ke lock screen
          final context = AppNavigator.currentContext;
          if (context != null && context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.deviceLostLock,
              (route) => false,
            );
          }
          break;

        case 'locate':
          final loc = await LocationService.getCurrentLocation();
          if (loc != null && SupabaseService.isInitialized) {
            final userId = SupabaseService().currentUserId;
            if (userId != null) {
              // Simpan ping lokasi ke server
              await SupabaseService().client.from('location_pings').insert({
                'session_id': payload['sessionId'],
                'latitude': loc.latitude,
                'longitude': loc.longitude,
                'accuracy': loc.accuracy,
              });
            }
          }
          break;

        default:
          _logger.w('DeviceCommandHandler: Tipe command tidak dikenal: $commandType');
      }

      // Tandai command sudah dieksekusi di database
      if (commandId != null && SupabaseService.isInitialized) {
        try {
          await SupabaseService().client.from('device_commands').update({
            'status': 'executed',
            'executed_at': DateTime.now().toIso8601String(),
          }).eq('id', commandId);
        } catch (_) {}
      }
    } catch (e, st) {
      _logger.e('DeviceCommandHandler.handle error: $e\n$st');
      if (commandId != null && SupabaseService.isInitialized) {
        try {
          await SupabaseService().client.from('device_commands').update({
            'status': 'failed',
          }).eq('id', commandId);
        } catch (_) {}
      }
    }
  }
}
