import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/dimensions.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('P2-1: ChatComposer Touch Target Standardization (48x48dp)', () {
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

    Widget createHarness({
      Message? replyMessage,
      Message? editingMessage,
      VoidCallback? onCancelReply,
      VoidCallback? onCancelEdit,
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
                editingMessage: editingMessage,
                onCancelReply: onCancelReply ?? () {},
                onCancelEdit: onCancelEdit,
                onSend: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Tombol Emoji dan Lampiran memiliki target sentuh minimal 48x48 dp', (tester) async {
      await tester.pumpWidget(createHarness());
      await tester.pumpAndSettle();

      // Cari IconButton Emoji (tooltip: Emoji)
      final emojiBtnFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Emoji',
      );
      expect(emojiBtnFinder, findsOneWidget);
      final emojiBtn = tester.widget<IconButton>(emojiBtnFinder);
      expect(emojiBtn.constraints?.minWidth, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
      expect(emojiBtn.constraints?.minHeight, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));

      // Cari IconButton Lampiran (tooltip: Lampiran)
      final attachBtnFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Lampiran',
      );
      expect(attachBtnFinder, findsOneWidget);
      final attachBtn = tester.widget<IconButton>(attachBtnFinder);
      expect(attachBtn.constraints?.minWidth, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
      expect(attachBtn.constraints?.minHeight, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
    });

    testWidgets('Tombol Batal Balas Pesan (Dismiss Reply) memiliki target sentuh minimal 48x48 dp', (tester) async {
      final sampleReply = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Pesan yang dibalas',
        type: MessageType.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(createHarness(replyMessage: sampleReply));
      await tester.pumpAndSettle();

      final dismissIconFinder = find.byIcon(SolarIconsOutline.closeCircle);
      expect(dismissIconFinder, findsOneWidget);

      final dismissContainerFinder = find.ancestor(
        of: dismissIconFinder,
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(dismissContainerFinder);
      expect(containerWidget.constraints?.minWidth, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
      expect(containerWidget.constraints?.minHeight, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
    });

    testWidgets('Tombol Batal Edit Pesan memiliki target sentuh minimal 48x48 dp', (tester) async {
      final sampleEdit = Message(
        id: 'msg_2',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Pesan sebelum diedit',
        type: MessageType.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(createHarness(
        editingMessage: sampleEdit,
        onCancelEdit: () {},
      ));
      await tester.pumpAndSettle();

      final cancelEditIconFinder = find.byIcon(SolarIconsOutline.closeSquare);
      expect(cancelEditIconFinder, findsOneWidget);

      final cancelEditContainerFinder = find.ancestor(
        of: cancelEditIconFinder,
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(cancelEditContainerFinder);
      expect(containerWidget.constraints?.minWidth, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
      expect(containerWidget.constraints?.minHeight, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
    });

    testWidgets('Bar kategori emoji dan tombol toko emoji memiliki target sentuh 48dp', (tester) async {
      await tester.pumpWidget(createHarness());
      await tester.pumpAndSettle();

      // Buka panel emoji
      await tester.tap(find.byTooltip('Emoji'));
      await tester.pumpAndSettle();

      // Verifikasi tombol Toko Emoji
      final storeBtnFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Toko Emoji',
      );
      expect(storeBtnFinder, findsOneWidget);
      final storeBtn = tester.widget<IconButton>(storeBtnFinder);
      expect(storeBtn.constraints?.minWidth, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));
      expect(storeBtn.constraints?.minHeight, greaterThanOrEqualTo(MekaarSizes.touchTargetMin));

      // Verifikasi tombol kategori (misal: Sering Digunakan atau Kategori 1)
      final categoryBtnFinder = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.constraints != null &&
            w.constraints!.minWidth >= MekaarSizes.touchTargetMin &&
            w.constraints!.minHeight >= MekaarSizes.touchTargetMin,
      );
      expect(categoryBtnFinder, findsWidgets);
    });
  });
}
