import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatComposer Adaptive Quick Action (Mic <-> Kamera Toggle) Tests', () {
    late TextEditingController textController;
    late FocusNode focusNode;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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
      GlobalKey<ChatComposerState>? key,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                key: key,
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

    testWidgets('Initial State: Default mode Mic, tombol mic aktif, micro-badge kamera tampil', (tester) async {
      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.mic);

      // Micro-badge di atas tombol aksi harus terlihat dengan icon kamera & panah ke atas
      expect(find.byIcon(SolarIconsOutline.altArrowUp), findsOneWidget);
      expect(find.bySemanticsLabel('Beralih ke kamera'), findsOneWidget);

      // Tombol aksi utama menampilkan icon mikrofon
      expect(find.bySemanticsLabel('Rekam suara'), findsOneWidget);
    });

    testWidgets('Swipe Up Gesture: Mengubah mode dari Mic ke Kamera dan sebaliknya', (tester) async {
      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.mic);

      // Cari tombol aksi kanan (Semantics "Rekam suara")
      final actionButton = find.bySemanticsLabel('Rekam suara');
      expect(actionButton, findsOneWidget);

      // Lakukan gestur drag ke atas (swipe up)
      await tester.drag(actionButton, const Offset(0, -60));
      await tester.pumpAndSettle();

      // State harus berubah menjadi camera
      expect(composerKey.currentState?.quickActionMode, QuickActionMode.camera);
      expect(find.bySemanticsLabel('Buka kamera'), findsOneWidget);
      expect(find.bySemanticsLabel('Beralih ke mikrofon'), findsOneWidget);

      // Swipe up lagi untuk beralih kembali ke Mic
      final cameraActionButton = find.bySemanticsLabel('Buka kamera');
      await tester.drag(cameraActionButton, const Offset(0, -60));
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.mic);
      expect(find.bySemanticsLabel('Rekam suara'), findsOneWidget);
      expect(find.bySemanticsLabel('Beralih ke kamera'), findsOneWidget);
    });

    testWidgets('Micro-badge Tap: Mengetuk micro-badge langsung menukar mode', (tester) async {
      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.mic);

      // Tap pada micro-badge
      final badge = find.bySemanticsLabel('Beralih ke kamera');
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.camera);
      expect(find.bySemanticsLabel('Buka kamera'), findsOneWidget);
    });

    testWidgets('Text Input: Micro-badge bersembunyi dan tombol aksi berubah menjadi Kirim', (tester) async {
      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Beralih ke kamera'), findsOneWidget);
      expect(find.bySemanticsLabel('Rekam suara'), findsOneWidget);

      // Masukkan teks ke dalam text controller
      textController.text = 'Halo Mekaar';
      await tester.pumpAndSettle();

      // Micro-badge harus disembunyikan
      expect(find.bySemanticsLabel('Beralih ke kamera'), findsNothing);
      expect(find.bySemanticsLabel('Beralih ke mikrofon'), findsNothing);

      // Tombol aksi berubah menjadi tombol kirim (plain)
      expect(find.bySemanticsLabel('Kirim pesan'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.plain), findsOneWidget);

      // Hapus teks kembali kosong
      textController.clear();
      await tester.pumpAndSettle();

      // Micro-badge dan tombol mic kembali terlihat
      expect(find.bySemanticsLabel('Beralih ke kamera'), findsOneWidget);
      expect(find.bySemanticsLabel('Rekam suara'), findsOneWidget);
    });

    testWidgets('Complementary Attachment Slot: Menyesuaikan opsi antara Buka Kamera dan Rekam Suara', (tester) async {
      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      // Saat mode Mic, buka attachment sheet
      final attachButton = find.byIcon(SolarIconsOutline.paperclip);
      expect(attachButton, findsOneWidget);
      await tester.tap(attachButton);
      await tester.pumpAndSettle();

      // Slot 2 harus "Buka Kamera"
      expect(find.text('Buka Kamera'), findsOneWidget);
      expect(find.text('Rekam Suara'), findsNothing);

      // Tutup sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Alihkan mode ke Camera via tap micro-badge
      await tester.tap(find.bySemanticsLabel('Beralih ke kamera'));
      await tester.pumpAndSettle();
      expect(composerKey.currentState?.quickActionMode, QuickActionMode.camera);

      // Buka attachment sheet lagi
      await tester.tap(attachButton);
      await tester.pumpAndSettle();

      // Sekarang Slot 2 harus "Rekam Suara" dan "Buka Kamera" tidak ada
      expect(find.text('Rekam Suara'), findsOneWidget);
      expect(find.text('Buka Kamera'), findsNothing);
    });

    testWidgets('Persistence: Preferensi mode Kamera dimuat dari SharedPreferences saat init', (tester) async {
      SharedPreferences.setMockInitialValues({
        'chat_composer_quick_action_mode': 'camera',
      });

      final composerKey = GlobalKey<ChatComposerState>();
      await tester.pumpWidget(createHarness(key: composerKey));
      await tester.pumpAndSettle();

      expect(composerKey.currentState?.quickActionMode, QuickActionMode.camera);
      expect(find.bySemanticsLabel('Buka kamera'), findsOneWidget);
      expect(find.bySemanticsLabel('Beralih ke mikrofon'), findsOneWidget);
    });
  });
}
