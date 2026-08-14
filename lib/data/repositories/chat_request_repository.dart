import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_request_model.dart';
import '../services/supabase_service.dart';
import 'block_repository.dart';
import '../../features/settings/providers/block_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class ChatRequestRepository {
  final SupabaseService _supabaseService;
  final BlockRepository _blockRepository;
  final Logger _log = Logger();

  ChatRequestRepository(this._supabaseService, this._blockRepository);

  SupabaseClient get _client => _supabaseService.client;

  /// Kirim Permintaan Chat baru dengan keterangan undangan (min 10 karakter)
  Future<ChatRequest> sendChatRequest({
    required String receiverId,
    required String invitationNote,
    bool viaQrCode = false,
  }) async {
    final senderId = _supabaseService.currentUserId;
    if (senderId == null) throw Exception('User belum login');

    if (!viaQrCode && invitationNote.trim().length < 10) {
      throw Exception('Keterangan undangan wajib diisi minimal 10 karakter');
    }

    try {
      final response = await _client
          .from('chat_requests')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'invitation_note': invitationNote.trim(),
            'status': viaQrCode ? 'accepted' : 'pending',
            'via_qr_code': viaQrCode,
          })
          .select()
          .single();

      return ChatRequest.fromMap(response);
    } catch (e) {
      _log.e('ChatRequestRepository: sendChatRequest failed: $e');
      rethrow;
    }
  }

  /// Ambil daftar Permintaan Chat Masuk yang masih 'pending'
  Future<List<ChatRequest>> fetchIncomingRequests() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('chat_requests')
          .select('*, sender_profile:profiles!chat_requests_sender_id_fkey(username, avatar_url)')
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).map((e) => ChatRequest.fromMap(e)).toList();
    } catch (e) {
      _log.w('ChatRequestRepository: fetchIncomingRequests failed: $e');
      return [];
    }
  }

  /// Stream count permintaan chat pending untuk badge tab
  Stream<int> streamPendingRequestsCount() {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return Stream.value(0);

    return _client
        .from('chat_requests')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((records) => records.where((r) => r['status'] == 'pending').length);
  }

  /// Setujui Permintaan Chat
  Future<void> acceptRequest(String requestId) async {
    try {
      await _client.from('chat_requests').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      _log.e('ChatRequestRepository: acceptRequest failed: $e');
      rethrow;
    }
  }

  /// Opsi 1: Tolak Permintaan Chat saja (saat ragu)
  Future<void> rejectRequest(String requestId) async {
    try {
      await _client.from('chat_requests').update({
        'status': 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      _log.e('ChatRequestRepository: rejectRequest failed: $e');
      rethrow;
    }
  }

  /// Opsi 2: Tolak & Blokir Pengundang sekaligus (saat yakin/terganggu)
  Future<void> rejectAndBlockRequest(String requestId, String senderId) async {
    try {
      await rejectRequest(requestId);
      await _blockRepository.blockUser(senderId);
      _log.i('ChatRequestRepository: rejected & blocked sender $senderId');
    } catch (e) {
      _log.e('ChatRequestRepository: rejectAndBlockRequest failed: $e');
      rethrow;
    }
  }

  /// Cek apakah relasi chat antara 2 pengguna sudah disetujui
  Future<bool> isChatApproved(String otherUserId) async {
    final currentUserId = _supabaseService.currentUserId;
    if (currentUserId == null) return false;

    try {
      // 1. Cek mode proteksi target user
      final profileResponse = await _client
          .from('profiles')
          .select('chat_invitation_mode')
          .eq('id', otherUserId)
          .maybeSingle();

      final mode = profileResponse?['chat_invitation_mode'] as String? ?? 'approved_only';
      if (mode == 'everyone') return true;

      // 2. Mode 'approved_only' — cek apakah ada chat_request yang accepted
      final response = await _client
          .from('chat_requests')
          .select('status')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false; // Safe-fail: tolak akses saat error
    }
  }
}

final chatRequestRepositoryProvider = Provider<ChatRequestRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final blockRepository = ref.watch(blockRepositoryProvider);
  return ChatRequestRepository(supabaseService, blockRepository);
});
