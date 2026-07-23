import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';

class CallRepository {
  final SupabaseClient _client;

  CallRepository(this._client);

  /// Catat baris panggilan baru dengan status 'ringing'
  Future<Map<String, dynamic>> createCall({
    required String roomId,
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
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

  /// Perbarui status panggilan ('answered', 'declined', 'missed', 'ended', 'failed')
  Future<void> updateCallStatus(String callId, String status) async {
    await _client.from('calls').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
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
