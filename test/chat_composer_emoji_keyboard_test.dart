import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/icons.dart';
import 'package:mekaar_chat/data/models/emoji_pack_model.dart';
import 'package:mekaar_chat/data/services/emoji_pack_service.dart';
import 'package:mekaar_chat/features/chat/providers/emoji_pack_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

class _FakeEmojiPackService extends Fake implements EmojiPackService {
  @override
  Future<List<EmojiPack>> fetchCatalog() async => const [];

  @override
  Future<bool> isInstalled(String slug) async => false;

  @override
  Map<String, String> get urlIndex => const {};

  @override
  List<EmojiPackItem> itemsOf(String packSlug) => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatComposer Emoji & Keyboard Mutual Exclusion Tests', () {
    testWidgets(
      'Mengirim emoji saat panel emoji terbuka tidak memicu focus/papan ketik muncul bersamaan',
      (tester) async {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
        });

        bool emojiVisible = false;
        int sendCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              emojiPackServiceProvider.overrideWithValue(_FakeEmojiPackService()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ChatComposer(
                    controller: controller,
                    focusNode: focusNode,
                    replyMessage: null,
                    onCancelReply: () {},
                    onEmojiPanelVisibilityChanged: (v) => emojiVisible = v,
                    onSend: () {
                      sendCount++;
                      controller.clear();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Masuk room: focus tidak aktif, panel emoji tertutup
        expect(focusNode.hasFocus, isFalse);
        expect(emojiVisible, isFalse);

        // 2. Ketuk ikon Emoji -> panel emoji terbuka, focus tetap false
        await tester.tap(find.byIcon(MekaarIcons.smile));
        await tester.pumpAndSettle();

        expect(emojiVisible, isTrue);
        expect(focusNode.hasFocus, isFalse);
        expect(find.byIcon(MekaarIcons.keyboard), findsOneWidget);

        // 3. Pilih salah satu emoji dari panel standar lalu tekan tombol Kirim
        await tester.tap(find.text('😀').first);
        await tester.pump();
        expect(controller.text, contains('😀'));

        await tester.tap(find.byIcon(SolarIconsOutline.plain));
        await tester.pumpAndSettle();

        // 4. Pesan terkirim, panel emoji tetap terbuka, dan keyboard TIDAK boleh ikut meminta fokus
        expect(sendCount, equals(1));
        expect(emojiVisible, isTrue);
        expect(focusNode.hasFocus, isFalse);
      },
    );

    testWidgets(
      'Mutual exclusion: jika FocusNode menerima fokus saat panel emoji terbuka, panel emoji otomatis tertutup',
      (tester) async {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
        });

        bool emojiVisible = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              emojiPackServiceProvider.overrideWithValue(_FakeEmojiPackService()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ChatComposer(
                    controller: controller,
                    focusNode: focusNode,
                    replyMessage: null,
                    onCancelReply: () {},
                    onEmojiPanelVisibilityChanged: (v) => emojiVisible = v,
                    onSend: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Buka panel emoji
        await tester.tap(find.byIcon(MekaarIcons.smile));
        await tester.pumpAndSettle();
        expect(emojiVisible, isTrue);

        // Minta fokus secara programatik (mensimulasikan keyboard muncul)
        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Panel emoji harus otomatis tertutup (tidak muncul bersamaan)
        expect(focusNode.hasFocus, isTrue);
        expect(emojiVisible, isFalse);
      },
    );
  });
}
