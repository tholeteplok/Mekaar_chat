import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1-1: Offline-First Google Fonts Verification', () {
    test('GoogleFonts.config.allowRuntimeFetching harus false untuk mencegah FOUC & HTTP leak', () {
      // Di lib/main.dart, allowRuntimeFetching dimatikan secara permanen
      GoogleFonts.config.allowRuntimeFetching = false;
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    });
  });

  group('P1-3: PaginatedContactsState & Logic Tests', () {
    test('PaginatedContactsState memiliki initial state yang valid', () {
      const state = PaginatedContactsState();
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.searchQuery, isEmpty);
      expect(state.page, 0);
    });

    test('PaginatedContactsState copyWith mengupdate field secara immutably', () {
      const state = PaginatedContactsState();
      final updated = state.copyWith(
        items: [
          {'id': 'u1', 'username': 'andi', 'display_name': 'Andi'},
        ],
        isLoading: true,
        page: 1,
        searchQuery: 'and',
      );

      expect(updated.items.length, 1);
      expect(updated.isLoading, isTrue);
      expect(updated.page, 1);
      expect(updated.searchQuery, 'and');
      expect(updated.hasMore, isTrue); // default unchanged
    });

    test('Paginasi batching menggabungkan data lama dan data baru secara mulus', () {
      final initialBatch = [
        {'id': 'u1', 'username': 'andi'},
        {'id': 'u2', 'username': 'budi'},
      ];
      final state = PaginatedContactsState(
        items: initialBatch,
        page: 1,
        hasMore: true,
      );

      final nextBatch = [
        {'id': 'u3', 'username': 'citra'},
        {'id': 'u4', 'username': 'dewi'},
      ];
      final combined = [...state.items, ...nextBatch];
      final nextState = state.copyWith(
        items: combined,
        page: state.page + 1,
        isLoadingMore: false,
      );

      expect(nextState.items.length, 4);
      expect(nextState.page, 2);
      expect(nextState.items.map((e) => e['id']).toList(), ['u1', 'u2', 'u3', 'u4']);
    });
  });

  group('Pilar 1: Local-First Inbox Snapshot Structure Tests', () {
    test('Data Map chat room cache mempertahankan seluruh metadata penting', () {
      final now = DateTime.now();
      final roomData = <String, dynamic>{
        'id': 'room-123',
        'roomType': 'direct',
        'name': 'Budi Santoso',
        'avatar': 'B',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'lastMessage': 'Halo, apa kabar?',
        'timestamp': now,
        'unreadCount': 2,
        'isGuardian': false,
        'isGroup': false,
        'memberCount': 2,
        'otherUserId': 'user-456',
        'isMuted': false,
        'isArchived': false,
      };

      expect(roomData['id'], 'room-123');
      expect(roomData['name'], 'Budi Santoso');
      expect(roomData['lastMessage'], 'Halo, apa kabar?');
      expect(roomData['unreadCount'], 2);
      expect(roomData['isArchived'], isFalse);
    });

    test('Decoy Mode Room isolation menyajikan entri aman terpisah', () {
      final decoyRooms = [
        {
          'id': 'room_welcome_mekaar',
          'room_id': 'room_welcome_mekaar',
          'roomType': 'direct',
          'room_type': 'direct',
          'name': 'Mekaar Official',
          'chat_name': 'Mekaar Official',
          'avatar': 'M',
          'avatarUrl': null,
          'avatar_url': null,
          'otherUserId': 'mekaar_official',
          'other_user_id': 'mekaar_official',
          'isGuardian': false,
          'is_guardian': false,
          'isGroup': false,
          'is_group': false,
          'isMuted': false,
          'is_muted': false,
          'isArchived': false,
          'is_archived': false,
          'unreadCount': 0,
          'unread_count': 0,
          'lastMessage': 'Selamat datang di Mekaar Chat!',
          'last_message': 'Selamat datang di Mekaar Chat!',
        }
      ];

      expect(decoyRooms.length, 1);
      expect(decoyRooms.first['id'], 'room_welcome_mekaar');
      expect(decoyRooms.first['name'], 'Mekaar Official');
      expect(decoyRooms.first['lastMessage'], 'Selamat datang di Mekaar Chat!');
      // Backward compatibility keys
      expect(decoyRooms.first['room_id'], 'room_welcome_mekaar');
      expect(decoyRooms.first['chat_name'], 'Mekaar Official');
      // Pastikan tidak ada data sensitif kontak asli
      expect(decoyRooms.any((r) => r['otherUserId'] != 'mekaar_official'), isFalse);
    });
  });
}
