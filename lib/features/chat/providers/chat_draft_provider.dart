import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_draft_model.dart';
import '../../../data/services/local_message_database.dart';

final chatDraftsProvider =
    StateNotifierProvider<ChatDraftsNotifier, Map<String, ChatDraft>>((ref) {
  return ChatDraftsNotifier(LocalMessageDatabase.instance);
});

class ChatDraftsNotifier extends StateNotifier<Map<String, ChatDraft>> {
  final LocalMessageDatabase _db;
  final Map<String, Timer> _debounceTimers = {};

  ChatDraftsNotifier(this._db) : super({}) {
    _loadInitialDrafts();
  }

  Future<void> _loadInitialDrafts() async {
    try {
      final initialDrafts = await _db.getAllDrafts();
      if (mounted) {
        state = initialDrafts;
      }
    } catch (_) {}
  }

  /// Memperbarui draf obrolan.
  /// 
  /// Aturan Keamanan Anti-Forensik:
  /// Jika [isBurnOnExit] bernilai true, draf HANYA disimpan di RAM (volatile)
  /// dan TIDAK PERNAH menyentuh disk SQLite fisik.
  void setDraft({
    required String roomId,
    required String content,
    String? replyToId,
    required bool isBurnOnExit,
    bool flushNow = false,
  }) {
    if (roomId.trim().isEmpty) return;

    if (content.trim().isEmpty && replyToId == null) {
      deleteDraft(roomId);
      return;
    }

    final draft = ChatDraft(
      roomId: roomId,
      content: content,
      replyToId: replyToId,
      updatedAt: DateTime.now(),
    );

    // Update state RAM seketika untuk reaktivitas UI 0ms
    state = {...state, roomId: draft};

    // Kebijakan Anti-Forensik: Burn on Exit = ZERO DISK RESIDUE
    if (isBurnOnExit) {
      _debounceTimers[roomId]?.cancel();
      _debounceTimers.remove(roomId);
      return;
    }

    if (flushNow) {
      _debounceTimers[roomId]?.cancel();
      _debounceTimers.remove(roomId);
      unawaited(_db.saveDraft(roomId, content, replyToId: replyToId));
    } else {
      _debounceTimers[roomId]?.cancel();
      _debounceTimers[roomId] = Timer(const Duration(milliseconds: 400), () {
        _debounceTimers.remove(roomId);
        _db.saveDraft(roomId, content, replyToId: replyToId);
      });
    }
  }

  /// Menghapus draf obrolan dari memori RAM dan disk SQLCipher
  void deleteDraft(String roomId) {
    if (roomId.trim().isEmpty) return;

    _debounceTimers[roomId]?.cancel();
    _debounceTimers.remove(roomId);

    if (state.containsKey(roomId)) {
      final updated = Map<String, ChatDraft>.from(state)..remove(roomId);
      state = updated;
    }

    unawaited(_db.deleteDraft(roomId));
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }
}
