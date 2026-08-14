import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/device_lost_model.dart';
import '../services/supabase_service.dart';

class DeviceLostRepository {
  final SupabaseService _supabaseService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _storageKey = 'device_lost_state';

  DeviceLostRepository(this._supabaseService);

  /// Load device lost lock state from secure storage
  Future<DeviceLostState> getDeviceLostState() async {
    try {
      final jsonStr = await _secureStorage.read(key: _storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return DeviceLostState.fromJson(map);
      }
    } catch (_) {}

    return const DeviceLostState();
  }

  /// Save device lost state locally and attempt cloud sync
  Future<void> setDeviceLostState(DeviceLostState state) async {
    try {
      final jsonStr = jsonEncode(state.toJson());
      await _secureStorage.write(key: _storageKey, value: jsonStr);
    } catch (_) {}

    // Cloud sync (Optional / Best Effort via Supabase profile metadata or sos_sessions)
    try {
      final userId = _supabaseService.currentUserId;
      if (userId != null) {
        await _supabaseService.client.from('profiles').update({
          'is_device_lost': state.isLocked,
          'lock_screen_message': state.lockMessage,
          'recovery_contact': state.recoveryContact,
        }).eq('id', userId);
      }
    } catch (_) {
      // Ignored silently if database migration columns do not exist yet
    }
  }

  /// Clear device lost state (unlock device)
  Future<void> clearDeviceLostState() async {
    await setDeviceLostState(const DeviceLostState(isLocked: false));
  }
}
