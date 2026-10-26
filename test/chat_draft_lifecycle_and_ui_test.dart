import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/models/chat_draft_model.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/features/chat/providers/chat_draft_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_list_tile.dart';
import 'package:mekaar_chat/features/settings/providers/privacy_provider.dart';

class MockLocalMessageDatabase extends Fake implements LocalMessageDatabase {
  final Map<String, ChatDraft> storage = {};
  int saveDraftCallCount = 0;
  int deleteDraftCallCount = 0;

  @override
  Future<Map<String, ChatDraft>> getAllDrafts() async => Map.from(storage);

  @override
  Future<ChatDraft?> getDraft(String roomId) async => storage[roomId];

  @override
  Future<void> saveDraft(String roomId, String content, {String? replyToId}) async {
    saveDraftCallCount++;
    storage[roomId] = ChatDraft(
      roomId: roomId,
      content: content,
      replyToId: replyToId,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteDraft(String roomId) async {
    deleteDraftCallCount++;
    storage.remove(roomId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatDraft Model Tests', () {
    test('Serialisasi toMap dan fromMap konsisten', () {
      final now = DateTime.now();
      final draft = ChatDraft(
        roomId: 'room_123',
        content: 'Pesan draf rahasia',
        replyToId: 'msg_999',
        updatedAt: now,
      );

      final map = draft.toMap();
      expect(map['room_id'], equals('room_123'));
      expect(map['content'], equals('Pesan draf rahasia'));
      expect(map['reply_to_id'], equals('msg_999'));
      expect(map['updated_at'], equals(now.millisecondsSinceEpoch));

      final restored = ChatDraft.fromMap(map);
      expect(restored.roomId, equals(draft.roomId));
      expect(restored.content, equals(draft.content));
      expect(restored.replyToId, equals(draft.replyToId));
      expect(restored.updatedAt.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('copyWith memperbarui field secara selektif', () {
      final now = DateTime.now();
      final draft = ChatDraft(
        roomId: 'room_1',
        content: 'Teks awal',
        replyToId: null,
        updatedAt: now,
      );

      final updated = draft.copyWith(content: 'Teks baru', replyToId: 'reply_1');
      expect(updated.roomId, equals('room_1'));
      expect(updated.content, equals('Teks baru'));
      expect(updated.replyToId, equals('reply_1'));
      expect(updated.updatedAt, equals(now));
    });
  });

  group('ChatDraftsNotifier & Anti-Forensic Lifecycle Tests', () {
    late MockLocalMessageDatabase mockDb;

    setUp(() {
      mockDb = MockLocalMessageDatabase();
    });

    test('setDraft mengupdate state RAM secara instan (0ms)', () {
      final notifier = ChatDraftsNotifier(mockDb);
      notifier.setDraft(
        roomId: 'room_abc',
        content: 'Halo draf',
        isBurnOnExit: false,
      );

      expect(notifier.state.containsKey('room_abc'), isTrue);
      expect(notifier.state['room_abc']!.content, equals('Halo draf'));
      notifier.dispose();
    });

    test('setDraft dengan flushNow: true langsung menyimpan ke database disk', () async {
      final notifier = ChatDraftsNotifier(mockDb);
      notifier.setDraft(
        roomId: 'room_abc',
        content: 'Draf instan',
        isBurnOnExit: false,
        flushNow: true,
      );

      expect(mockDb.saveDraftCallCount, equals(1));
      expect(mockDb.storage['room_abc']?.content, equals('Draf instan'));
      notifier.dispose();
    });

    test('Anti-Forensik: isBurnOnExit: true TIDAK PERNAH menyentuh disk SQLite', () async {
      final notifier = ChatDraftsNotifier(mockDb);
      notifier.setDraft(
        roomId: 'burn_room_1',
        content: 'Pesan sangat rahasia',
        isBurnOnExit: true,
        flushNow: true,
      );

      // Pastikan ada di RAM untuk kenyamanan UX selama di layar
      expect(notifier.state['burn_room_1']?.content, equals('Pesan sangat rahasia'));

      // Verifikasi anti-forensik: Disk TIDAK PERNAH disentuh
      expect(mockDb.saveDraftCallCount, equals(0));
      expect(mockDb.storage.containsKey('burn_room_1'), isFalse);

      notifier.dispose();
    });

    test('deleteDraft menghapus draf dari RAM dan memicu penghapusan database', () async {
      mockDb.storage['room_del'] = ChatDraft(
        roomId: 'room_del',
        content: 'Akan dihapus',
        updatedAt: DateTime.now(),
      );

      final notifier = ChatDraftsNotifier(mockDb);
      notifier.setDraft(
        roomId: 'room_del',
        content: 'Akan dihapus',
        isBurnOnExit: false,
      );
      expect(notifier.state.containsKey('room_del'), isTrue);

      notifier.deleteDraft('room_del');
      expect(notifier.state.containsKey('room_del'), isFalse);
      expect(mockDb.deleteDraftCallCount, equals(1));
      expect(mockDb.storage.containsKey('room_del'), isFalse);

      notifier.dispose();
    });

    test('Mengirim string kosong otomatis memicu deleteDraft', () async {
      final notifier = ChatDraftsNotifier(mockDb);
      notifier.setDraft(
        roomId: 'room_empty',
        content: 'Sebelumnya ada',
        isBurnOnExit: false,
      );
      expect(notifier.state.containsKey('room_empty'), isTrue);

      notifier.setDraft(
        roomId: 'room_empty',
        content: '   ',
        replyToId: null,
        isBurnOnExit: false,
      );
      expect(notifier.state.containsKey('room_empty'), isFalse);
      expect(mockDb.deleteDraftCallCount, equals(1));

      notifier.dispose();
    });
  });

  group('ChatListTile Draf UI Indicator Tests', () {
    testWidgets('ChatListTile menampilkan label "Draf: " dengan warna softCoral saat draf aktif', (tester) async {
      final roomData = {
        'id': 'room_draft_test',
        'name': 'Budi Santoso',
        'avatar': 'B',
        'lastMessage': 'Halo ini pesan kemarin',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'unreadCount': 0,
        'isGuardian': false,
        'isGroup': false,
      };

      final draft = ChatDraft(
        roomId: 'room_draft_test',
        content: 'Rencana pertemuan besok pagi',
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatDraftsProvider.overrideWith((ref) => FakeChatDraftsNotifier({'room_draft_test': draft})),
            stealthChatPreviewProvider.overrideWith((ref) => FakeStealthChatPreviewNotifier(false)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: roomData,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Label "Draf: " harus muncul di layar
      expect(find.textContaining('Draf: '), findsOneWidget);
      expect(find.textContaining('Rencana pertemuan besok pagi'), findsOneWidget);
      // Pesan lama "Halo ini pesan kemarin" tertutupi oleh cuplikan draf
      expect(find.text('Halo ini pesan kemarin'), findsNothing);
    });

    testWidgets('Stealth Mode: Draf disamarkan menjadi "Draf: ••••••••"', (tester) async {
      final roomData = {
        'id': 'room_stealth_draft',
        'name': 'Agus Rahasia',
        'avatar': 'A',
        'lastMessage': 'Pesan lama',
        'timestamp': DateTime.now(),
        'unreadCount': 0,
      };

      final draft = ChatDraft(
        roomId: 'room_stealth_draft',
        content: 'Data sangat rahasia jangan dilihat',
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatDraftsProvider.overrideWith((ref) => FakeChatDraftsNotifier({'room_stealth_draft': draft})),
            stealthChatPreviewProvider.overrideWith((ref) => FakeStealthChatPreviewNotifier(true)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: roomData,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Draf: '), findsOneWidget);
      expect(find.textContaining('••••••••'), findsOneWidget);
      expect(find.textContaining('Data sangat rahasia jangan dilihat'), findsNothing);
    });

    testWidgets('Saat draf kosong atau tidak ada, ChatListTile menampilkan lastMessage normal', (tester) async {
      final roomData = {
        'id': 'room_no_draft',
        'name': 'Siti Rahma',
        'avatar': 'S',
        'lastMessage': 'Sampai ketemu besok!',
        'timestamp': DateTime.now(),
        'unreadCount': 0,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatDraftsProvider.overrideWith((ref) => FakeChatDraftsNotifier({})),
            stealthChatPreviewProvider.overrideWith((ref) => FakeStealthChatPreviewNotifier(false)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: roomData,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Draf: '), findsNothing);
      expect(find.text('Sampai ketemu besok!'), findsOneWidget);
    });
  });
}

class FakeChatDraftsNotifier extends ChatDraftsNotifier {
  FakeChatDraftsNotifier(Map<String, ChatDraft> initial)
      : super(MockLocalMessageDatabase()..storage.addAll(initial)) {
    state = initial;
  }
}

class FakeStealthChatPreviewNotifier extends StealthChatPreviewNotifier {
  FakeStealthChatPreviewNotifier(bool initial) : super() {
    state = initial;
  }
}
