import 'dart:async';

import '../services/supabase_service.dart';

class RoomForwardingProtection {
  final bool effective;
  final bool callerEnabled;
  final int protectorCount;
  final int participantCount;
  final DateTime? lastChange;
  final bool isFromCache;

  const RoomForwardingProtection({
    required this.effective,
    required this.callerEnabled,
    required this.protectorCount,
    required this.participantCount,
    required this.lastChange,
    this.isFromCache = false,
  });

  /// Fail-closed: kalau status belum diketahui/gagal dimuat, ANGGAP
  /// forwarding protection AKTIF (lebih aman salah menganggap terlindungi
  /// daripada salah menganggap tidak, persis prinsip RoomScreenProtection).
  const RoomForwardingProtection.failClosed()
      : effective = true,
        callerEnabled = true,
        protectorCount = 0,
        participantCount = 0,
        lastChange = null,
        isFromCache = true;

  factory RoomForwardingProtection.fromJson(Map<String, dynamic> json) {
    return RoomForwardingProtection(
      effective: json['effective'] as bool? ?? true,
      callerEnabled: json['caller_enabled'] as bool? ?? true,
      protectorCount: (json['protector_count'] as num?)?.toInt() ?? 0,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      lastChange: DateTime.tryParse(json['last_change'] as String? ?? ''),
    );
  }
}

class ForwardingProtectionRepository {
  final SupabaseService _supabase;

  ForwardingProtectionRepository(this._supabase);

  Future<RoomForwardingProtection> getRoomState(String roomId) async {
    final response = await _supabase.client.rpc(
      'get_room_forwarding_protection',
      params: {'p_room_id': roomId},
    );
    if (response is List && response.isNotEmpty) {
      return RoomForwardingProtection.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    }
    return const RoomForwardingProtection.failClosed();
  }

  Future<void> setRoomPreference(String roomId, bool enabled) async {
    await _supabase.client.rpc(
      'set_room_forwarding_protection',
      params: {'p_room_id': roomId, 'p_enabled': enabled},
    );
  }

  Stream<void> watchRoomChanges(String roomId) {
    return _supabase.client
        .from('room_participants')
        .stream(primaryKey: ['room_id', 'profile_id'])
        .eq('room_id', roomId)
        .map((_) {});
  }
}
