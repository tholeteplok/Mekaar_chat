import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';

class CallRepository {
  final SupabaseClient _client;

  CallRepository(this._client);

  /// Catat baris panggilan baru dengan status 'ringing'
  /// Memverifikasi hubungan chat sebelum mengizinkan panggilan
  Future<Map<String, dynamic>> createCall({
    required String roomId,
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
    // Verifikasi izin chat & keanggotaan room sebelum panggilan
    final isApproved = await _isChatApprovedForCall(
      callerId,
      receiverId,
      roomId: roomId,
    );
    if (!isApproved) {
      throw Exception(
        'Chat belum disetujui atau bukan partisipan room yang sah.',
      );
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

  /// Cek internal apakah relasi chat sah untuk melakukan panggilan
  Future<bool> _isChatApprovedForCall(
    String userId,
    String otherUserId, {
    String? roomId,
  }) async {
    try {
      // 1. Jika roomId tersedia, cek apakah kedua pengguna adalah partisipan sah di room tersebut
      if (roomId != null && roomId.isNotEmpty) {
        final participants = await _client
            .from('room_participants')
            .select('profile_id')
            .eq('room_id', roomId)
            .inFilter('profile_id', [userId, otherUserId]);

        final matchedIds = (participants as List)
            .map((p) => p['profile_id'] as String?)
            .whereType<String>()
            .toSet();

        if (matchedIds.contains(userId) && matchedIds.contains(otherUserId)) {
          return true;
        }
      }

      // 2. Cek relasi Guardian aktif (Guardian selalu berhak memanggil / dipanggil)
      final guardianRow = await _client
          .from('guardians')
          .select('id')
          .or(
            'and(user_id.eq.$userId,guardian_id.eq.$otherUserId),and(user_id.eq.$otherUserId,guardian_id.eq.$userId)',
          )
          .eq('status', 'active')
          .maybeSingle();
      if (guardianRow != null) return true;

      // 3. Cek mode proteksi target user
      final profileResponse = await _client
          .from('profiles')
          .select('chat_invitation_mode')
          .eq('id', otherUserId)
          .maybeSingle();

      final mode =
          profileResponse?['chat_invitation_mode'] as String? ??
          'approved_only';
      if (mode == 'everyone') return true;

      // 4. Mode approved_only — cek chat_requests yang disetujui
      final response = await _client
          .from('chat_requests')
          .select('status')
          .or(
            'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)',
          )
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (_) {
      // Fallback: Jika query pengecekan gagal tapi roomId valid, izinkan inisialisasi
      if (roomId != null && roomId.isNotEmpty) return true;
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
