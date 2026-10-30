import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/utils/chat_search_helper.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_app_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeSearchHits Unit Tests', () {
    final now = DateTime.now();

    final m1 = Message(
      id: 'msg-1',
      roomId: 'r1',
      senderId: 'u1',
      content: 'Kucing oranye bermain bola',
      type: MessageType.text,
      createdAt: now.subtract(const Duration(minutes: 10)),
      updatedAt: now.subtract(const Duration(minutes: 10)),
    );

    final m2 = Message(
      id: 'msg-2',
      roomId: 'r1',
      senderId: 'u2',
      content: 'Ada anjing lucu di taman',
      type: MessageType.text,
      createdAt: now.subtract(const Duration(minutes: 5)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
    );

    final m3 = Message(
      id: 'msg-3',
      roomId: 'r1',
      senderId: 'u1',
      content: 'KUCING itu tidur nyenyak',
      type: MessageType.text,
      createdAt: now.subtract(const Duration(minutes: 1)),
      updatedAt: now.subtract(const Duration(minutes: 1)),
    );

    final mFile = Message(
      id: 'msg-4',
      roomId: 'r1',
      senderId: 'u2',
      content: jsonEncode({
        'key': 'KEY123',
        'file_name': 'kucing_persia.pdf',
        'file_size': 1024,
      }),
      type: MessageType.file,
      createdAt: now,
      updatedAt: now,
    );

    test('Menemukan pesan yang cocok dan menyortir terbaru ke terlama', () {
      final hits = computeSearchHits(
        messages: [m1, m2, m3, mFile],
        query: 'kucing',
      );

      expect(hits.length, equals(3));
      // Urutan: mFile (terbaru), lalu m3, lalu m1 (terlama)
      expect(hits[0].messageId, equals('msg-4'));
      expect(hits[1].messageId, equals('msg-3'));
      expect(hits[2].messageId, equals('msg-1'));
    });

    test('Mengabaikan pesan yang terdaftar dalam hiddenMessageIds', () {
      final hits = computeSearchHits(
        messages: [m1, m2, m3, mFile],
        query: 'kucing',
        hiddenMessageIds: {'msg-3'},
      );

      expect(hits.length, equals(2));
      expect(hits.any((h) => h.messageId == 'msg-3'), isFalse);
    });

    test(
      'Mengembalikan list kosong jika kueri kosong atau tidak ditemukan',
      () {
        expect(computeSearchHits(messages: [m1, m2], query: '   '), isEmpty);
        expect(computeSearchHits(messages: [m1, m2], query: 'gajah'), isEmpty);
      },
    );
  });

  group('ChatAppBar Navigation Controls Widget Tests', () {
    testWidgets(
      'Merender indikator X/Y dan tombol ▲▼ saat mode navigasi aktif',
      (tester) async {
        bool prevTapped = false;
        bool nextTapped = false;
        bool toggleTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatAppBar(
                  chatId: 'test-chat',
                  chatName: 'Grup Pengujian',
                  avatarInitial: 'G',
                  isGuardian: false,
                  isGroup: true,
                  otherLastSeenNotifier: ValueNotifier<DateTime?>(null),
                  isMuted: false,
                  isSelectionMode: false,
                  totalSelectedCount: 0,
                  selectedMessageIds: const {},
                  selectedCallIds: const {},
                  rawMessages: const [],
                  onClearSelection: () {},
                  onReplySelectedMessage: () {},
                  onEditSelectedMessage: (_) {},
                  onCopySelectedMessages: () {},
                  onForwardSelectedMessages: () {},
                  onDownloadSelectedFiles: (_) {},
                  onSaveSelectedToVault: (_) {},
                  onDeleteSelectedMessages: (_) {},
                  // Search
                  isSearching: true,
                  searchQuery: 'penting',
                  searchResultCount: 4,
                  isFilterMode: false,
                  onToggleFilterMode: () => toggleTapped = true,
                  currentHitIndex: 1, // 0-based -> posisi ke-2
                  totalHitCount: 4,
                  onPreviousHit: () => prevTapped = true,
                  onNextHit: () => nextTapped = true,
                  searchController: TextEditingController(text: 'penting'),
                  inChatSearchFocusNode: FocusNode(),
                  onCloseSearch: () {},
                  onSearchChanged: (_) {},
                  onClearSearchQuery: () {},
                  onAvatarTap: () {},
                  onInitiateCall: (_) {},
                  onMenuActionSelected: (_) {},
                ),
              ),
            ),
          ),
        );

        // Verifikasi indikator hit "2/4"
        expect(find.text('2/4'), findsOneWidget);

        // Verifikasi tombol panah ▲ (lebih lama)
        final prevBtn = find.byKey(const ValueKey('search_prev_hit_button'));
        expect(prevBtn, findsOneWidget);
        await tester.tap(prevBtn);
        expect(prevTapped, isTrue);

        // Verifikasi tombol panah ▼ (lebih baru)
        final nextBtn = find.byKey(const ValueKey('search_next_hit_button'));
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        expect(nextTapped, isTrue);

        // Verifikasi tombol toggle mode
        final toggleBtn = find.byTooltip('Beralih ke mode saring');
        expect(toggleBtn, findsOneWidget);
        await tester.tap(toggleBtn);
        expect(toggleTapped, isTrue);
      },
    );

    testWidgets(
      'Merender badge hasil dan menyembunyikan tombol panah saat mode saring (filter mode) aktif',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatAppBar(
                  chatId: 'test-chat',
                  chatName: 'Grup Pengujian',
                  avatarInitial: 'G',
                  isGuardian: false,
                  isGroup: true,
                  otherLastSeenNotifier: ValueNotifier<DateTime?>(null),
                  isMuted: false,
                  isSelectionMode: false,
                  totalSelectedCount: 0,
                  selectedMessageIds: const {},
                  selectedCallIds: const {},
                  rawMessages: const [],
                  onClearSelection: () {},
                  onReplySelectedMessage: () {},
                  onEditSelectedMessage: (_) {},
                  onCopySelectedMessages: () {},
                  onForwardSelectedMessages: () {},
                  onDownloadSelectedFiles: (_) {},
                  onSaveSelectedToVault: (_) {},
                  onDeleteSelectedMessages: (_) {},
                  // Search
                  isSearching: true,
                  searchQuery: 'penting',
                  searchResultCount: 3,
                  isFilterMode: true, // Mode Saring
                  onToggleFilterMode: () {},
                  currentHitIndex: 0,
                  totalHitCount: 3,
                  onPreviousHit: () {},
                  onNextHit: () {},
                  searchController: TextEditingController(text: 'penting'),
                  inChatSearchFocusNode: FocusNode(),
                  onCloseSearch: () {},
                  onSearchChanged: (_) {},
                  onClearSearchQuery: () {},
                  onAvatarTap: () {},
                  onInitiateCall: (_) {},
                  onMenuActionSelected: (_) {},
                ),
              ),
            ),
          ),
        );

        // Tampilkan badge "3 hasil"
        expect(find.text('3 hasil'), findsOneWidget);

        // Tombol panah ▲ dan ▼ tidak ditampilkan dalam mode saring
        expect(
          find.byKey(const ValueKey('search_prev_hit_button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('search_next_hit_button')),
          findsNothing,
        );

        // Tooltip toggle berubah
        expect(
          find.byTooltip('Beralih ke mode sorot & lompat'),
          findsOneWidget,
        );
      },
    );
  });
}
