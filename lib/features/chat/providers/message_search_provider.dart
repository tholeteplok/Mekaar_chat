import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/message_search_repository.dart';
import '../../../data/services/local_message_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/block_provider.dart';
import 'chat_provider.dart';
import 'private_vault_provider.dart';

/// Provider repositori pencarian pesan lokal SQLCipher
final messageSearchRepositoryProvider = Provider<MessageSearchRepository>((
  ref,
) {
  return LocalMessageSearchRepository(LocalMessageDatabase.instance);
});

/// State string query pencarian lintas-chat
final messageSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

/// Hasil pencarian pesan lintas-chat secara flat
final messageSearchResultsProvider = FutureProvider.autoDispose<List<Message>>((
  ref,
) async {
  final rawQuery = ref.watch(messageSearchQueryProvider);
  final query = rawQuery.trim();
  if (query.length < 2) return const [];

  // Watch auth state agar hasil otomatis invalidate saat switch mode Decoy atau logout
  ref.watch(authProvider);

  final cloakedRooms = ref.watch(cloakedRoomIdsProvider);
  final hiddenRooms = ref.watch(hiddenRoomIdsProvider);
  final cloakedContacts = ref.watch(cloakedContactUserIdsProvider);
  final blockedIds = ref
      .watch(blockProvider)
      .maybeWhen(
        data: (list) => list.map((b) => b.blockedId).toSet(),
        orElse: () => <String>{},
      );
  final isAnyUnlocked =
      ref.watch(unlockedVaultSlotsProvider).isNotEmpty ||
      ref.watch(privateVaultUnlockedProvider);

  final excludedRoomIds = <String>{...cloakedRooms};
  if (!isAnyUnlocked) {
    excludedRoomIds.addAll(hiddenRooms);
  }

  final rooms =
      ref.watch(chatRoomsProvider).value ?? const <Map<String, dynamic>>[];
  for (final r in rooms) {
    final id = (r['id'] ?? r['room_id']) as String?;
    final otherUserId = (r['otherUserId'] ?? r['other_user_id']) as String?;
    if (id != null && otherUserId != null) {
      if (cloakedContacts.contains(otherUserId) ||
          blockedIds.contains(otherUserId)) {
        excludedRoomIds.add(id);
      }
    }
  }

  final repo = ref.watch(messageSearchRepositoryProvider);
  return repo.searchMessages(
    query: query,
    excludedRoomIds: excludedRoomIds,
    limit: 100,
  );
});

/// Representasi grup hasil pencarian per room percakapan
class RoomSearchResultGroup {
  final String roomId;
  final String roomName;
  final String roomAvatar;
  final String? roomAvatarUrl;
  final bool isGuardian;
  final String? otherUserId;
  final List<Message> messages;

  const RoomSearchResultGroup({
    required this.roomId,
    required this.roomName,
    required this.roomAvatar,
    this.roomAvatarUrl,
    this.isGuardian = false,
    this.otherUserId,
    required this.messages,
  });
}

/// Provider hasil pencarian yang telah dikelompokkan berdasarkan percakapan (room)
final groupedSearchResultsProvider =
    Provider.autoDispose<AsyncValue<List<RoomSearchResultGroup>>>((ref) {
      final searchResultsAsync = ref.watch(messageSearchResultsProvider);
      final rooms =
          ref.watch(chatRoomsProvider).value ?? const <Map<String, dynamic>>[];

      return searchResultsAsync.whenData((messages) {
        if (messages.isEmpty) return const [];

        final roomMap = <String, Map<String, dynamic>>{};
        for (final r in rooms) {
          final id = (r['id'] ?? r['room_id']) as String?;
          if (id != null) {
            roomMap[id] = r;
          }
        }

        final groupsMap = <String, List<Message>>{};
        for (final m in messages) {
          groupsMap.putIfAbsent(m.roomId, () => []).add(m);
        }

        final groups = <RoomSearchResultGroup>[];
        for (final entry in groupsMap.entries) {
          final roomId = entry.key;
          final roomData = roomMap[roomId];
          final rawName =
              roomData?['name'] as String? ??
              roomData?['chat_name'] as String? ??
              'Obrolan';
          final rawAvatar =
              roomData?['avatar'] as String? ??
              (rawName.isNotEmpty ? rawName[0].toUpperCase() : '💬');
          final avatarUrl =
              roomData?['avatarUrl'] as String? ??
              roomData?['avatar_url'] as String?;
          final isGuardian =
              roomData?['isGuardian'] as bool? ??
              roomData?['is_guardian'] as bool? ??
              false;
          final otherUserId =
              (roomData?['otherUserId'] ?? roomData?['other_user_id'])
                  as String?;

          groups.add(
            RoomSearchResultGroup(
              roomId: roomId,
              roomName: rawName,
              roomAvatar: rawAvatar,
              roomAvatarUrl: avatarUrl,
              isGuardian: isGuardian,
              otherUserId: otherUserId,
              messages: entry.value,
            ),
          );
        }

        return groups;
      });
    });
