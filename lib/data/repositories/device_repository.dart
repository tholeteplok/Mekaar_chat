import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_device.dart';
import '../services/device_identity_service.dart';

/// Repository untuk mengelola perangkat terdaftar (tabel `user_devices`).
///
/// Menangani:
/// - Registrasi perangkat saat app start / token refresh
/// - Listing semua perangkat milik user
/// - Revoke (hapus) perangkat tertentu
/// - Clear FCM token saat logout (hanya device ini)
class DeviceRepository {
  final SupabaseClient _client;
  static final Logger _logger = Logger();

  DeviceRepository(this._client);

  /// Register atau update device saat app start / FCM token refresh.
  /// Dipanggil dari [PushNotificationService] sebagai pengganti `update_fcm_token`.
  Future<void> registerDevice({String? fcmToken}) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final label = await DeviceIdentityService.getDeviceLabel();
      final platform = DeviceIdentityService.getPlatform();

      String? appVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (_) {}

      await _client.rpc('register_device', params: {
        'p_device_id': deviceId,
        'p_fcm_token': fcmToken,
        'p_device_label': label,
        'p_platform': platform,
        'p_app_version': appVersion,
      });

      _logger.i(
        'DeviceRepository: Device terdaftar '
        '(id=$deviceId, label=$label, platform=$platform)',
      );
    } catch (e, st) {
      _logger.w('DeviceRepository.registerDevice gagal: $e\n$st');
      // Fallback: coba RPC lama agar push tetap bisa diterima
      // selama transisi (migrasi 72 belum dijalankan di produksi)
      if (fcmToken != null) {
        try {
          await _client.rpc('update_fcm_token', params: {'p_token': fcmToken});
          _logger.i('DeviceRepository: Fallback ke update_fcm_token berhasil');
        } catch (_) {}
      }
    }
  }

  /// List semua perangkat terdaftar milik user saat ini.
  Future<List<UserDevice>> listMyDevices() async {
    try {
      final result = await _client.rpc('list_my_devices');
      final list = result as List<dynamic>;
      return list
          .map((e) => UserDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.w('DeviceRepository.listMyDevices gagal: $e\n$st');
      return [];
    }
  }

  /// Revoke (hapus) perangkat tertentu, kirim remote command 'logout', dan clear FCM token-nya.
  /// Dipanggil dari UI "Perangkat Terhubung" saat user memilih "Keluar".
  Future<void> revokeDevice(String deviceId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      // 1. Kirim silent remote command 'logout' ke perangkat target
      if (userId != null) {
        try {
          await _client.from('device_commands').insert({
            'target_profile_id': userId,
            'target_device_id': deviceId,
            'command_type': 'logout',
            'sender_profile_id': userId,
            'status': 'pending',
          });
        } catch (_) {}
      }

      // 2. Hapus baris dari user_devices
      await _client.rpc('revoke_device', params: {'p_device_id': deviceId});
      _logger.i('DeviceRepository: Device $deviceId di-revoke & remote logout dikirim');
    } catch (e, st) {
      _logger.w('DeviceRepository.revokeDevice gagal: $e\n$st');
      rethrow;
    }
  }

  /// Revoke semua perangkat SELAIN perangkat saat ini.
  Future<void> revokeAllOtherDevices() async {
    final currentDeviceId = await DeviceIdentityService.getDeviceId();
    final devices = await listMyDevices();

    for (final device in devices) {
      if (device.deviceId != currentDeviceId) {
        try {
          await revokeDevice(device.deviceId);
        } catch (_) {
          // Lanjutkan ke device berikutnya meskipun gagal
        }
      }
    }
  }

  /// Clear FCM token hanya untuk device ini (saat logout).
  /// Menggantikan RPC `clear_fcm_token` yang menghapus semua.
  Future<void> clearFcmTokenForThisDevice() async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      await _client.rpc(
        'clear_device_fcm_token',
        params: {'p_device_id': deviceId},
      );
      _logger.i('DeviceRepository: FCM token cleared untuk device $deviceId');
    } catch (e) {
      _logger.w('DeviceRepository.clearFcmTokenForThisDevice gagal: $e');
      // Fallback ke RPC lama
      try {
        await _client.rpc('clear_fcm_token');
      } catch (_) {}
    }
  }

  /// Mendapatkan device_id perangkat saat ini (helper untuk UI).
  Future<String> getCurrentDeviceId() async {
    return DeviceIdentityService.getDeviceId();
  }
}

/// Riverpod provider untuk DeviceRepository.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(Supabase.instance.client);
});
