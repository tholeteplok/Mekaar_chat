import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/mekaar_link_text.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_app_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageSearchText Unit Tests', () {
    test('Pesan teks biasa mengembalikan content utuh', () {
      final msg = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Halo apa kabar dunia!',
        type: MessageType.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(msg.searchableText, equals('Halo apa kabar dunia!'));
    });

    test('Pesan teks kosong atau spasi mengembalikan null', () {
      final msg = Message(
        id: 'msg-2',
        roomId: 'room-1',
        senderId: 'user-1',
        content: '   \n  \t ',
        type: MessageType.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(msg.searchableText, isNull);
    });

    test(
      'Pesan terhapus, silent deleted, atau view-once mengembalikan null',
      () {
        final base = Message(
          id: 'msg-3',
          roomId: 'room-1',
          senderId: 'user-1',
          content: 'Pesan sensitif',
          type: MessageType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(base.copyWith(isDeleted: true).searchableText, isNull);
        expect(base.copyWith(isSilentDeleted: true).searchableText, isNull);
        expect(base.copyWith(isViewOnce: true).searchableText, isNull);
      },
    );

    test(
      'Pesan kedaluwarsa (autoDeleteAt di masa lalu) mengembalikan null',
      () {
        final expired = Message(
          id: 'msg-4',
          roomId: 'room-1',
          senderId: 'user-1',
          content: 'Pesan sementara',
          type: MessageType.text,
          autoDeleteAt: DateTime.now().subtract(const Duration(minutes: 5)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(expired.searchableText, isNull);

        final active = expired.copyWith(
          autoDeleteAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(active.searchableText, equals('Pesan sementara'));
      },
    );

    test(
      'Pesan berkas (file) hanya mengembalikan nama berkas dan caption, TANPA bocor kunci',
      () {
        const secretKey = 'TOP_SECRET_AES_GCM_ENCRYPTION_KEY_B64';
        final fileJson = jsonEncode({
          'key': secretKey,
          'file_name': 'laporan_keuangan_q3.pdf',
          'file_size': 1048576,
          'mime_type': 'application/pdf',
          'caption': 'Draft audit final',
        });

        final msg = Message(
          id: 'msg-5',
          roomId: 'room-1',
          senderId: 'user-1',
          content: fileJson,
          type: MessageType.file,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final text = msg.searchableText;
        expect(text, isNotNull);
        expect(text, contains('laporan_keuangan_q3.pdf'));
        expect(text, contains('Draft audit final'));
        // Verifikasi kunci enkripsi dan metadata teknis JSON TIDAK bocor ke searchableText
        expect(text!.contains(secretKey), isFalse);
        expect(text.contains('file_size'), isFalse);
        expect(text.contains('mime_type'), isFalse);
      },
    );

    test(
      'Pesan gambar dan video mengembalikan caption jika ada, TANPA bocor kunci',
      () {
        const imgKey = 'IMAGE_AES_KEY_BASE64_BYTES';
        final imgJson = jsonEncode({
          'key': imgKey,
          'caption': 'Foto dokumentasi lapangan',
        });

        final imgMsg = Message(
          id: 'msg-6',
          roomId: 'room-1',
          senderId: 'user-1',
          content: imgJson,
          type: MessageType.image,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(imgMsg.searchableText, equals('Foto dokumentasi lapangan'));
        expect(imgMsg.searchableText!.contains(imgKey), isFalse);

        final imgNoCaption = Message(
          id: 'msg-7',
          roomId: 'room-1',
          senderId: 'user-1',
          content: jsonEncode({'key': imgKey}),
          type: MessageType.image,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(imgNoCaption.searchableText, isNull);
      },
    );

    test('Pesan voice, location, dan system mengembalikan null', () {
      final now = DateTime.now();
      expect(
        Message(
          id: 'v1',
          roomId: 'r',
          senderId: 'u',
          content: '{"duration": 12}',
          type: MessageType.voice,
          createdAt: now,
          updatedAt: now,
        ).searchableText,
        isNull,
      );
      expect(
        Message(
          id: 'l1',
          roomId: 'r',
          senderId: 'u',
          content: '-6.2088,106.8456',
          type: MessageType.location,
          createdAt: now,
          updatedAt: now,
        ).searchableText,
        isNull,
      );
      expect(
        Message(
          id: 's1',
          roomId: 'r',
          senderId: 'u',
          content: 'Panggilan selesai',
          type: MessageType.system,
          createdAt: now,
          updatedAt: now,
        ).searchableText,
        isNull,
      );
    });
  });

  group('MekaarLinkText Highlight Widget Tests', () {
    List<TextSpan> extractLeafSpans(InlineSpan root) {
      final leaves = <TextSpan>[];
      void traverse(InlineSpan span) {
        if (span is TextSpan) {
          if (span.children != null && span.children!.isNotEmpty) {
            for (final child in span.children!) {
              traverse(child);
            }
          } else {
            leaves.add(span);
          }
        }
      }

      traverse(root);
      return leaves;
    }

    testWidgets(
      'Merender sorotan latar belakang amber pada teks yang cocok (case-insensitive)',
      (tester) async {
        const sampleText = 'Ini adalah kata rahasia yang sangat penting.';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MekaarLinkText(
                text: sampleText,
                baseStyle: TextStyle(color: Colors.black, fontSize: 16),
                highlightQuery: 'rahasia',
              ),
            ),
          ),
        );

        final richTextFinder = find.descendant(
          of: find.byType(MekaarLinkText),
          matching: find.byType(RichText),
        );
        expect(richTextFinder, findsOneWidget);

        final richText = tester.widget<RichText>(richTextFinder);
        final leaves = extractLeafSpans(richText.text);

        // Cari span dengan warna latar amber (highlight)
        final highlighted = leaves.where((span) {
          return span.style?.backgroundColor ==
              MekaarColors.warnAmber.withValues(alpha: 0.35);
        }).toList();

        expect(highlighted.length, equals(1));
        expect(highlighted.first.text, equals('rahasia'));
      },
    );

    testWidgets(
      'Merender sorotan pada bagian URL yang cocok tanpa menghilangkan navigasi',
      (tester) async {
        const sampleText = 'Kunjungi https://rahasia.mekaar.id/panduan segera.';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MekaarLinkText(
                text: sampleText,
                baseStyle: TextStyle(color: Colors.black, fontSize: 16),
                highlightQuery: 'rahasia',
              ),
            ),
          ),
        );

        final richTextFinder = find.descendant(
          of: find.byType(MekaarLinkText),
          matching: find.byType(RichText),
        );
        expect(richTextFinder, findsOneWidget);

        final richText = tester.widget<RichText>(richTextFinder);
        final leaves = extractLeafSpans(richText.text);

        // Cari span URL yang ter-highlight
        final highlighted = leaves.where((span) {
          return span.text == 'rahasia' &&
              span.style?.backgroundColor ==
                  MekaarColors.warnAmber.withValues(alpha: 0.35);
        }).toList();

        expect(highlighted.length, equals(1));
        // Recognizer tetap terpasang
        expect(highlighted.first.recognizer, isNotNull);
      },
    );
  });

  group('ChatAppBar Search Result Count Widget Tests', () {
    testWidgets(
      'Menampilkan badge "N hasil" saat pencarian aktif dengan hasil > 0',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatAppBar(
                  chatId: 'test-chat',
                  chatName: 'Teman Bicara',
                  avatarInitial: 'T',
                  isGuardian: false,
                  isGroup: false,
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
                  isSearching: true,
                  searchQuery: 'halo',
                  searchResultCount: 7,
                  searchController: TextEditingController(text: 'halo'),
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

        expect(find.text('7 hasil'), findsOneWidget);
      },
    );
  });
}
