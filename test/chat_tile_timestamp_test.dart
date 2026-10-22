import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_list_tile.dart';

class _FakeChatRepository implements ChatRepository {
  final List<Map<String, dynamic>> _rooms;
  _FakeChatRepository(this._rooms);

  @override
  Future<List<Map<String, dynamic>>> getRooms() async => _rooms;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatListTile Timestamp Type Tolerance', () {
    testWidgets('Renders properly when timestamp is a DateTime', (tester) async {
      final now = DateTime(2026, 10, 22, 14, 30);
      final room = <String, dynamic>{
        'id': 'room-1',
        'name': 'Budi Santoso',
        'avatar': 'B',
        'avatarUrl': null,
        'lastMessage': 'Halo apa kabar?',
        'timestamp': now,
        'unreadCount': 2,
        'isGuardian': false,
        'isGroup': false,
        'isMuted': false,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ChatListTile(
                    room: room,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Halo apa kabar?'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(ChatListTile), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Renders properly without TypeError when timestamp is a String (ISO-8601)', (tester) async {
      final now = DateTime(2026, 10, 22, 14, 30);
      final room = <String, dynamic>{
        'id': 'room-2',
        'name': 'Siti Rahma',
        'avatar': 'S',
        'avatarUrl': null,
        'lastMessage': 'Siap, terima kasih!',
        'timestamp': now.toIso8601String(), // String format!
        'unreadCount': 0,
        'isGuardian': true,
        'isGroup': false,
        'isMuted': false,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ChatListTile(
                    room: room,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verifikasi tidak terjadi crash ErrorWidget (kartu abu-abu)
      expect(find.text('Siti Rahma'), findsOneWidget);
      expect(find.text('Siap, terima kasih!'), findsOneWidget);
      expect(find.byType(ChatListTile), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Renders gracefully when timestamp is null', (tester) async {
      final room = <String, dynamic>{
        'id': 'room-3',
        'name': 'Kontak Baru',
        'avatar': 'K',
        'avatarUrl': null,
        'lastMessage': null,
        'timestamp': null,
        'unreadCount': 0,
        'isGuardian': false,
        'isGroup': false,
        'isMuted': false,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ChatListTile(
                    room: room,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kontak Baru'), findsOneWidget);
      expect(find.byType(ChatListTile), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });

  group('ChatRoomsNotifier updateLastMessageLocally Type Integrity', () {
    test('Preserves timestamp as DateTime when updating locally', () async {
      final initialTime = DateTime(2026, 10, 22, 10, 0);
      final repo = _FakeChatRepository([
        {
          'id': 'room-xyz',
          'name': 'Test User',
          'lastMessage': 'Pesan lama',
          'timestamp': initialTime,
          'unreadCount': 0,
        }
      ]);

      final notifier = ChatRoomsNotifier(repo);
      await pumpEventQueue();

      final updatedTime = DateTime(2026, 10, 22, 14, 45);
      notifier.updateLastMessageLocally(
        roomId: 'room-xyz',
        previewText: 'Pesan baru terkirim',
        timestamp: updatedTime,
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
      );

      final rooms = notifier.state.value!;
      expect(rooms.first['lastMessage'], 'Pesan baru terkirim');
      expect(rooms.first['timestamp'], isA<DateTime>());
      expect(rooms.first['timestamp'], updatedTime);
    });
  });
}
