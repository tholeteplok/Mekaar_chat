import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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
/// - `locate`: Mengirim koordinat GPS perangkat ini kembali ke server
/// - `logout`: Keluar dari sesi perangkat secara jarak jauh
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

        case 'locate':
          final loc = await LocationService.getCurrentLocation();
          if (loc != null && SupabaseService.isInitialized) {
            // Update device_commands dengan koordinat hasil pelacakan di payload
            if (commandId != null) {
              try {
                await SupabaseService().client.from('device_commands').update({
                  'payload': {
                    ...payload,
                    'latitude': loc.latitude,
                    'longitude': loc.longitude,
                    'accuracy': loc.accuracy,
                    'located_at': DateTime.now().toIso8601String(),
                  },
                }).eq('id', commandId);
              } catch (_) {}
            }

            if (payload['sessionId'] != null) {
              try {
                await SupabaseService().client.from('location_pings').insert({
                  'session_id': payload['sessionId'],
                  'latitude': loc.latitude,
                  'longitude': loc.longitude,
                  'accuracy': loc.accuracy,
                });
              } catch (_) {}
            }
          }
          break;

        case 'logout':
          if (SupabaseService.isInitialized) {
            try {
              await SupabaseService().client.auth.signOut(scope: SignOutScope.local);
            } catch (_) {}
          }
          final navContext = AppNavigator.currentContext;
          if (navContext != null && navContext.mounted) {
            Navigator.of(navContext).pushNamedAndRemoveUntil(
              AppRoutes.onboarding,
              (route) => false,
            );
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
