import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_search_field.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/message_search_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/message_search_provider.dart';
import 'package:mekaar_chat/features/chat/screens/message_search_screen.dart';
import 'package:mekaar_chat/features/chat/utils/message_search_helper.dart';

/// Fake repository pencarian pesan dalam memori untuk pengujian offline-first
class FakeMessageSearchRepository implements MessageSearchRepository {
  List<Message> allMessages = [];

  @override
  Future<List<Message>> searchMessages({
    required String query,
    Set<String> excludedRoomIds = const {},
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) return [];

    final now = DateTime.now();
    final results = <Message>[];

    for (final m in allMessages) {
      if (m.isDeleted || m.isSilentDeleted || m.isViewOnce) continue;
      if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now)) continue;
      if (excludedRoomIds.contains(m.roomId)) continue;

      final text = m.searchableText;
      if (text != null && text.toLowerCase().contains(trimmed)) {
        results.add(m);
      }
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results.skip(offset).take(limit).toList();
  }
}

class _FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  _FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
    : super(AsyncValue.data(rooms));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<void> reloadFromLocalCache({
    bool syncRemoteInBackground = true,
  }) async {}

  @override
  Future<String> getOrCreateRoom(
    String otherUserId,
    String type, {
    bool screenshotEnabled = true,
  }) async => 'mock-room-id';

  @override
  void updateLastMessageLocally({
    required String roomId,
    required String previewText,
    required DateTime timestamp,
    required bool isFromOtherUser,
    bool isCurrentlyInRoom = false,
  }) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX-10 Fase C: MessageSearchHelper.buildFtsQuery Unit Tests', () {
    test('Membersihkan operator khusus dan kata kunci FTS', () {
      expect(
        MessageSearchHelper.buildFtsQuery('halo dunia'),
        equals('"halo" "dunia"*'),
      );
      expect(MessageSearchHelper.buildFtsQuery('  halo   '), equals('"halo"*'));
      expect(
        MessageSearchHelper.buildFtsQuery('"a" OR b*'),
        equals('"a" "b"*'),
      );
      expect(
        MessageSearchHelper.buildFtsQuery('NEAR(x y)'),
        equals('"x" "y"*'),
      );
    });

    test('Menolak query kurang dari 2 karakter atau hanya berisi operator', () {
      expect(MessageSearchHelper.buildFtsQuery('-x'), isNull);
      expect(MessageSearchHelper.buildFtsQuery('a'), isNull);
      expect(MessageSearchHelper.buildFtsQuery(''), isNull);
      expect(MessageSearchHelper.buildFtsQuery('    '), isNull);
      expect(MessageSearchHelper.buildFtsQuery('AND OR NOT NEAR'), isNull);
    });

    test('Mendukung query dengan tanda kutip ganda internal & multi-kata', () {
      expect(
        MessageSearchHelper.buildFtsQuery('bantuan darurat'),
        equals('"bantuan" "darurat"*'),
      );
      expect(
        MessageSearchHelper.buildFtsQuery('laporan "rahasia" keamanan'),
        equals('"laporan" "rahasia" "keamanan"*'),
      );
    });
  });

  group('UX-10 Fase C: buildSearchSnippetSegments & Spans Unit Tests', () {
    test('Menghasilkan segmen kecocokan dengan benar untuk teks pendek', () {
      final segments = MessageSearchHelper.buildSearchSnippetSegments(
        'Kunci cadangan ada di meja',
        'cadangan',
      );

      expect(segments.length, equals(3));
      expect(segments[0].text, equals('Kunci '));
      expect(segments[0].isMatch, isFalse);
      expect(segments[1].text, equals('cadangan'));
      expect(segments[1].isMatch, isTrue);
      expect(segments[2].text, equals(' ada di meja'));
      expect(segments[2].isMatch, isFalse);
    });

    test(
      'Memotong cuplikan dengan elipsis untuk teks panjang di sekitar kecocokan',
      () {
        const longPrefix =
            'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod ';
        const longSuffix =
            ' tempor incididunt ut labore et dolore magna aliqua ut enim ad minim veniam';
        final fullText = '${longPrefix}RAHASIA$longSuffix';

        final segments = MessageSearchHelper.buildSearchSnippetSegments(
          fullText,
          'rahasia',
          windowChars: 20,
        );

        expect(
          segments.any((s) => s.isMatch && s.text.toLowerCase() == 'rahasia'),
          isTrue,
        );
        expect(segments.first.text.startsWith('...'), isTrue);
        expect(segments.last.text.endsWith('...'), isTrue);
      },
    );

    test(
      'buildSearchSnippetSpans menerapkan gaya matchStyle pada segmen cocok',
      () {
        const normalStyle = TextStyle(color: Colors.grey);
        const matchStyle = TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
        );

        final spans = MessageSearchHelper.buildSearchSnippetSpans(
          text: 'Halo kawan apa kabar',
          query: 'kawan',
          normalStyle: normalStyle,
          matchStyle: matchStyle,
        );

        expect(spans.length, equals(3));
        final matchSpan = spans[1] as TextSpan;
        expect(matchSpan.text, equals('kawan'));
        expect(matchSpan.style, equals(matchStyle));
      },
    );
  });

  group('UX-10 Fase C: MessageSearchRepository & Invariant Keamanan Tests', () {
    late FakeMessageSearchRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeMessageSearchRepository();
      fakeRepo.allMessages = [
        Message(
          id: 'msg_1',
          roomId: 'room_1',
          senderId: 'user_a',
          content: 'Halo kawan, ini pesan penting',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        Message(
          id: 'msg_deleted',
          roomId: 'room_1',
          senderId: 'user_a',
          content: 'Ini pesan penting yang dihapus',
          type: MessageType.text,
          isDeleted: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        Message(
          id: 'msg_view_once',
          roomId: 'room_1',
          senderId: 'user_a',
          content: 'Pesan sekali lihat penting',
          type: MessageType.text,
          isViewOnce: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        Message(
          id: 'msg_file',
          roomId: 'room_2',
          senderId: 'user_b',
          content:
              '{"file_name":"Dokumen_Penting.pdf","file_size":1024,"key":"SECRET_AES_KEY_DO_NOT_LEAK","caption":"Laporan penting"}',
          type: MessageType.file,
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        Message(
          id: 'msg_vault_room',
          roomId: 'room_vault',
          senderId: 'user_c',
          content: 'Catatan penting dalam brankas',
          type: MessageType.text,
          createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ];
    });

    test(
      'Pesan view-once dan pesan terhapus tidak pernah muncul di hasil',
      () async {
        final results = await fakeRepo.searchMessages(query: 'penting');
        final ids = results.map((m) => m.id).toSet();

        expect(ids.contains('msg_1'), isTrue);
        expect(ids.contains('msg_file'), isTrue);
        expect(ids.contains('msg_deleted'), isFalse);
        expect(ids.contains('msg_view_once'), isFalse);
      },
    );

    test(
      'Pencarian terhadap kunci AES lampiran file tidak menghasilkan apa pun',
      () async {
        final results = await fakeRepo.searchMessages(query: 'SECRET_AES_KEY');
        expect(results, isEmpty);
      },
    );

    test(
      'excludedRoomIds mengecualikan room brankas tertutup dengan sempurna',
      () async {
        final results = await fakeRepo.searchMessages(
          query: 'penting',
          excludedRoomIds: {'room_vault'},
        );
        final roomIds = results.map((m) => m.roomId).toSet();

        expect(roomIds.contains('room_1'), isTrue);
        expect(roomIds.contains('room_2'), isTrue);
        expect(roomIds.contains('room_vault'), isFalse);
      },
    );
  });

  group('UX-10 Fase C: Penjaga Arsitektur (Zero Network Import)', () {
    test(
      'File pencarian pesan tidak mengimpor supabase atau HTTP network packages',
      () {
        final filesToCheck = [
          'lib/features/chat/utils/message_search_helper.dart',
          'lib/data/repositories/message_search_repository.dart',
          'lib/features/chat/providers/message_search_provider.dart',
          'lib/features/chat/screens/message_search_screen.dart',
        ];

        for (final filePath in filesToCheck) {
          final file = File(filePath);
          expect(file.existsSync(), isTrue, reason: '$filePath must exist');
          final content = file.readAsStringSync();

          expect(
            content.contains('package:supabase_flutter'),
            isFalse,
            reason:
                '$filePath dilarang mengimpor supabase_flutter (wajib offline-first)',
          );
          expect(
            content.contains("package:http/"),
            isFalse,
            reason: '$filePath dilarang mengimpor modul HTTP',
          );
        }
      },
    );
  });

  group('UX-10 Fase C: MessageSearchScreen Widget Tests', () {
    late FakeMessageSearchRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeMessageSearchRepository();
      fakeRepo.allMessages = [
        Message(
          id: 'msg_101',
          roomId: 'room_alpha',
          senderId: 'user_target',
          content: 'Halo, ini nomor darurat saya',
          type: MessageType.text,
          createdAt: DateTime(2026, 10, 30, 8, 30),
          updatedAt: DateTime(2026, 10, 30, 8, 30),
        ),
        Message(
          id: 'msg_102',
          roomId: 'room_beta',
          senderId: 'my_id',
          content: 'Siaga satu darurat',
          type: MessageType.text,
          createdAt: DateTime(2026, 10, 30, 9, 0),
          updatedAt: DateTime(2026, 10, 30, 9, 0),
        ),
      ];
    });

    testWidgets(
      'Menampilkan instruksi awal saat query kurang dari 2 karakter',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              messageSearchRepositoryProvider.overrideWithValue(fakeRepo),
              messageSearchQueryProvider.overrideWith((ref) => ''),
            ],
            child: const MaterialApp(home: MessageSearchScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(MekaarSearchField), findsOneWidget);
        expect(find.text('Cari Isi Pesan'), findsOneWidget);
        expect(find.textContaining('Ketik minimal 2 karakter'), findsOneWidget);
      },
    );

    testWidgets(
      'Menampilkan hasil terkelompok per room dengan cuplikan ber-highlight',
      (tester) async {
        final mockRooms = [
          {
            'id': 'room_alpha',
            'name': 'Ahmad Dahlan',
            'avatar': 'A',
            'isGuardian': true,
          },
          {
            'id': 'room_beta',
            'name': 'Budi Santoso',
            'avatar': 'B',
            'isGuardian': false,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              messageSearchRepositoryProvider.overrideWithValue(fakeRepo),
              messageSearchQueryProvider.overrideWith((ref) => 'darurat'),
              chatRoomsProvider.overrideWith(
                (ref) => _FakeChatRoomsNotifier(mockRooms),
              ),
            ],
            child: const MaterialApp(home: MessageSearchScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Memastikan kedua nama room dan sender label muncul
        expect(find.text('Ahmad Dahlan'), findsNWidgets(2));
        expect(find.text('Budi Santoso'), findsNWidgets(2));

        // Memastikan badge jumlah hasil muncul
        expect(find.text('1 hasil'), findsNWidgets(2));

        // Memastikan teks cuplikan pesan muncul
        expect(find.byType(RichText), findsWidgets);
      },
    );
  });
}
