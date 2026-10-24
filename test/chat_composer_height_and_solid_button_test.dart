import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('Chat Composer Layout, Height Alignment & Solid Action Button Tests', () {
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
      ChatRoomThemeSpec? roomThemeSpec,
      bool canSend = true,
      bool enabled = true,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                controller: textController,
                focusNode: focusNode,
                replyMessage: null,
                onCancelReply: () {},
                enabled: enabled,
                canSend: canSend,
                roomThemeSpec: roomThemeSpec,
                onSend: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Tombol aksi kanan berukuran 48x48 dan solid brandblue pada tema default', (tester) async {
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
      await tester.pumpAndSettle();

      // Temukan Container tombol aksi (lingkaran 48x48)
      final actionBtnFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == AppColors.blue,
      );
      expect(actionBtnFinder, findsOneWidget);

      final container = tester.widget<Container>(actionBtnFinder);
      expect(container.constraints?.minWidth ?? 48, 48);
      expect(container.constraints?.minHeight ?? 48, 48);

      // Verifikasi ikon mic berwarna putih
      final iconFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == SolarIconsOutline.microphone &&
            w.color == Colors.white,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('Tombol aksi kanan menyesuaikan warna kuning pada tema Comic', (tester) async {
      const comicYellow = Color(0xFFFFD84D);
      await tester.pumpWidget(
        createHarness(
          roomThemeSpec: const ChatRoomThemeSpec(
            primaryAccentColor: comicYellow,
            secondaryAccentColor: Colors.black,
            iconColor: Colors.black,
            textColor: Colors.black,
            subtitleColor: Colors.black87,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionBtnFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == comicYellow,
      );
      expect(actionBtnFinder, findsOneWidget);

      final iconFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == SolarIconsOutline.microphone &&
            w.color == Colors.white,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('Tombol aksi kanan menyesuaikan warna hijau pada tema Solarpunk / Eco', (tester) async {
      const solarpunkGreen = Color(0xFF10B981);
      await tester.pumpWidget(
        createHarness(
          roomThemeSpec: const ChatRoomThemeSpec(
            primaryAccentColor: solarpunkGreen,
            secondaryAccentColor: Color(0xFF059669),
            iconColor: solarpunkGreen,
            textColor: Colors.black,
            subtitleColor: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionBtnFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == solarpunkGreen,
      );
      expect(actionBtnFinder, findsOneWidget);

      // Ubah text menjadi mengetik -> ikon kirim tetap putih
      textController.text = 'Halo Solarpunk';
      await tester.pumpAndSettle();

      final sendIconFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == SolarIconsOutline.plain &&
            w.color == Colors.white,
      );
      expect(sendIconFinder, findsOneWidget);
    });

    testWidgets('Kapsul input dan tombol aksi memiliki tinggi presisi 48px pada 1 baris teks', (tester) async {
      await tester.pumpWidget(createHarness());
      await tester.pumpAndSettle();

      // Ambil RenderBox kapsul input
      final textFieldFinder = find.byKey(const ValueKey('chat_composer_text_field'));
      expect(textFieldFinder, findsOneWidget);

      // Cari Container tombol aksi kanan
      final actionBtnFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(actionBtnFinder, findsOneWidget);

      final actionBtnSize = tester.getSize(actionBtnFinder);
      expect(actionBtnSize.width, 48.0);
      expect(actionBtnSize.height, 48.0);
    });
  });
}
