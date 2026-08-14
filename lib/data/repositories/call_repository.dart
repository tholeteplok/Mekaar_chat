import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';

class CallRepository {
  final SupabaseClient _client;

  CallRepository(this._client);

  /// Catat baris panggilan baru dengan status 'ringing'
  /// Memverifikasi chat sudah disetujui sebelum mengizinkan panggilan
  Future<Map<String, dynamic>> createCall({
    required String roomId,
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
    // Verifikasi chat approval sebelum panggilan
    final isApproved = await _isChatApprovedForCall(callerId, receiverId);
    if (!isApproved) {
      throw Exception('Chat belum disetujui. Tidak dapat melakukan panggilan.');
    }

    final response = await _client
        .from('calls')
        .insert({
          'room_id': roomId,
          'caller_id': callerId,
          'receiver_id': receiverId,
          'call_type': callType,
          'status': 'ringing',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  /// Cek internal apakah relasi chat sudah disetujui untuk panggilan
  Future<bool> _isChatApprovedForCall(String userId, String otherUserId) async {
    try {
      // Cek mode proteksi target user
      final profileResponse = await _client
          .from('profiles')
          .select('chat_invitation_mode')
          .eq('id', otherUserId)
          .maybeSingle();

      final mode = profileResponse?['chat_invitation_mode'] as String? ?? 'approved_only';
      if (mode == 'everyone') return true;

      // Mode approved_only — cek chat_requests
      final response = await _client
          .from('chat_requests')
          .select('status')
          .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Perbarui status panggilan ('answered', 'declined', 'busy', 'missed', 'ended', 'failed')
  Future<void> updateCallStatus(
    String callId,
    String status, {
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (startedAt != null) updates['started_at'] = startedAt.toIso8601String();
    if (endedAt != null) updates['ended_at'] = endedAt.toIso8601String();
    if (durationSeconds != null) updates['duration_seconds'] = durationSeconds;

    await _client.from('calls').update(updates).eq('id', callId);
  }

  /// Mengakhiri panggilan dan mencatat durasi secara otomatis
  Future<void> endCall(String callId, {DateTime? startedAt}) async {
    final now = DateTime.now();
    int duration = 0;
    if (startedAt != null) {
      duration = now.difference(startedAt).inSeconds;
      if (duration < 0) duration = 0;
    }
    await updateCallStatus(
      callId,
      'ended',
      startedAt: startedAt,
      endedAt: now,
      durationSeconds: duration,
    );
  }

  /// Ambil detail panggilan berdasarkan ID
  Future<Map<String, dynamic>?> getCall(String callId) async {
    final response = await _client
        .from('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();
    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  final supabase = ref.read(supabaseServiceProvider);
  return CallRepository(supabase.client);
});
