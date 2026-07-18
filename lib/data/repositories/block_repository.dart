import '../models/blocked_user_model.dart';
import '../services/supabase_service.dart';

class BlockRepository {
  final SupabaseService _supabaseService;

  BlockRepository(this._supabaseService);

  Future<List<BlockedUser>> listBlocked() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];
    try {
      final response = await _supabaseService.client
          .from('user_blocks')
          .select()
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => BlockedUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isBlocked(String blockedId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return false;
    try {
      final response = await _supabaseService.client.rpc(
        'is_blocked_by_me',
        params: {'blocked_id': blockedId},
      );
      return response == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> blockUser(String blockedId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _supabaseService.client.from('user_blocks').insert({
      'blocker_id': userId,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser(String blockedId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _supabaseService.client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', blockedId);
  }
}
