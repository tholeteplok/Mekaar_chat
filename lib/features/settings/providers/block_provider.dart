import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/blocked_user_model.dart';
import '../../../data/repositories/block_repository.dart';
import '../../auth/providers/auth_provider.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return BlockRepository(supabaseService);
});

class BlockNotifier extends StateNotifier<AsyncValue<List<BlockedUser>>> {
  final BlockRepository _repo;

  BlockNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.listBlocked();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Set of blocked user ids for O(1) lookups (chat list filter, etc).
  Set<String> get blockedIds {
    return state.maybeWhen(
      data: (list) => list.map((b) => b.blockedId).toSet(),
      orElse: () => {},
    );
  }

  Future<void> blockUser(String blockedId) async {
    try {
      await _repo.blockUser(blockedId);
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> unblockUser(String blockedId) async {
    try {
      await _repo.unblockUser(blockedId);
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final blockProvider =
    StateNotifierProvider<BlockNotifier, AsyncValue<List<BlockedUser>>>((ref) {
      final repo = ref.watch(blockRepositoryProvider);
      return BlockNotifier(repo);
    });
