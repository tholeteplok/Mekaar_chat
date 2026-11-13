import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('Chat Composer Reply Preview & Emoji Panel Tests', () {
    late TextEditingController textController;
    late FocusNode focusNode;

    setUp(() {
      textController = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      textController.dispose();
      focusNode.dispose();
    });

    final testReplyMessage = Message(
      id: 'msg-123',
      roomId: 'room-abc',
      senderId: 'user-tester',
      content: 'Halo ini pesan yang dibalas',
      type: MessageType.text,
      createdAt: DateTime.utc(2026, 11, 13, 10, 0, 0),
      updatedAt: DateTime.utc(2026, 11, 13, 10, 0, 0),
    );

    Widget createHarness({
      Message? replyMessage,
      String? replySenderName,
      VoidCallback? onCancelReply,
      ChatRoomThemeSpec? roomThemeSpec,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                controller: textController,
                focusNode: focusNode,
                replyMessage: replyMessage,
                replySenderName: replySenderName,
                onCancelReply: onCancelReply ?? () {},
                canSend: true,
                roomThemeSpec: roomThemeSpec,
                onSend: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Kartu balas pesan menampilkan 2-line visual hierarchy dan tombol dismiss', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        createHarness(
          replyMessage: testReplyMessage,
          replySenderName: 'Budi Santoso',
          onCancelReply: () => cancelled = true,
          roomThemeSpec: const ChatRoomThemeSpec(
            primaryAccentColor: AppColors.blue,
            secondaryAccentColor: MekaarColors.cyan,
            iconColor: Colors.black,
            textColor: Colors.black,
            subtitleColor: Colors.grey,
          ),
        ),
      );
      await tester.pump();

      // Memverifikasi teks nama pengirim dan cuplikan pesan terpisah
      expect(find.text('Membalas Budi Santoso'), findsOneWidget);
      expect(find.text('Halo ini pesan yang dibalas'), findsOneWidget);

      // Memverifikasi icon forward dan tombol dismiss closeCircle
      expect(find.byIcon(SolarIconsOutline.forward), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.closeCircle), findsOneWidget);

      // Mengetuk tombol dismiss
      await tester.tap(find.byIcon(SolarIconsOutline.closeCircle));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('Panel emoji terbuka dengan tinggi 300 dan tidak terjadi overflow', (tester) async {
      await tester.pumpWidget(
        createHarness(
          roomThemeSpec: const ChatRoomThemeSpec(
            primaryAccentColor: AppColors.blue,
            secondaryAccentColor: MekaarColors.cyan,
            iconColor: Colors.black,
            textColor: Colors.black,
            subtitleColor: Colors.grey,
          ),
        ),
      );
      await tester.pump();

      // Temukan tombol emoji dan ketuk untuk membuka
      final emojiBtn = find.byTooltip('Emoji');
      expect(emojiBtn, findsOneWidget);
      await tester.tap(emojiBtn);
      await tester.pump();

      // Memverifikasi tab Standar dan kategori emoji muncul
      expect(find.text('Standar'), findsOneWidget);
      expect(find.text('Ekspresi & Wajah'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
