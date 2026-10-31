import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/constants/icons.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';
import 'package:mekaar_chat/data/models/emoji_pack_model.dart';
import 'package:mekaar_chat/features/chat/providers/emoji_pack_provider.dart';
import 'package:mekaar_chat/features/settings/providers/chat_theme_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';

class _FakeChatThemeNotifier
    extends StateNotifier<AsyncValue<ChatThemePreference>>
    implements ChatThemeNotifier {
  _FakeChatThemeNotifier(ChatThemePreference pref)
    : super(AsyncValue.data(pref));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEmojiCatalogController extends EmojiCatalogController {
  @override
  Future<List<EmojiPack>> build() async => [];
}

class _FakeInstalledPacksController extends InstalledPacksController {
  @override
  InstalledPacksState build() => const InstalledPacksState(slugs: {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatComposer Font Size & Dynamic Emoji/Keyboard Toggle Tests', () {
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
      double textScale = 1.0,
      GlobalKey<ChatComposerState>? key,
    }) {
      return ProviderScope(
        overrides: [
          chatThemeProvider.overrideWith(
            (ref) => _FakeChatThemeNotifier(
              ChatThemePreference(textScale: textScale),
            ),
          ),
          emojiCatalogProvider.overrideWith(_FakeEmojiCatalogController.new),
          installedPacksProvider.overrideWith(
            _FakeInstalledPacksController.new,
          ),
        ],
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
                enabled: true,
                canSend: true,
                onSend: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Ukuran font TextField composer default adalah 16.0 (100% cocok dengan bubble)',
      (tester) async {
        await tester.pumpWidget(createHarness(textScale: 1.0));
        await tester.pumpAndSettle();

        final textFieldFinder = find.byKey(
          const ValueKey('chat_composer_text_field'),
        );
        expect(textFieldFinder, findsOneWidget);

        final TextField textField = tester.widget(textFieldFinder);
        expect(textField.style?.fontSize, equals(16.0));
        expect(textField.decoration?.hintStyle?.fontSize, equals(16.0));
      },
    );

    testWidgets(
      'Ukuran font TextField composer membesar saat textScale 1.25x -> 20.0',
      (tester) async {
        await tester.pumpWidget(createHarness(textScale: 1.25));
        await tester.pumpAndSettle();

        final TextField textField = tester.widget(
          find.byKey(const ValueKey('chat_composer_text_field')),
        );
        expect(textField.style?.fontSize, closeTo(20.0, 0.001));
        expect(textField.decoration?.hintStyle?.fontSize, closeTo(20.0, 0.001));
      },
    );

    testWidgets(
      'Ukuran font TextField composer mengecil saat textScale 0.8x -> 12.8',
      (tester) async {
        await tester.pumpWidget(createHarness(textScale: 0.8));
        await tester.pumpAndSettle();

        final TextField textField = tester.widget(
          find.byKey(const ValueKey('chat_composer_text_field')),
        );
        expect(textField.style?.fontSize, closeTo(12.8, 0.001));
        expect(textField.decoration?.hintStyle?.fontSize, closeTo(12.8, 0.001));
      },
    );

    testWidgets(
      'Ikon default adalah smile (tooltip Emoji), saat diklik bertransisi jadi keyboard (tooltip Keyboard)',
      (tester) async {
        final composerKey = GlobalKey<ChatComposerState>();
        await tester.pumpWidget(createHarness(key: composerKey));
        await tester.pumpAndSettle();

        // 1. Awal: panel emoji tertutup -> Ikon smile, tooltip 'Emoji'
        expect(find.byTooltip('Emoji'), findsOneWidget);
        expect(find.byIcon(MekaarIcons.smile), findsOneWidget);
        expect(find.byIcon(SolarIconsOutline.keyboard), findsNothing);

        // 2. Klik tombol emoji -> Panel emoji terbuka -> Ikon berganti jadi keyboard
        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Keyboard'), findsOneWidget);
        expect(find.byIcon(MekaarIcons.keyboard), findsOneWidget);
        expect(find.byIcon(MekaarIcons.smile), findsNothing);

        // 3. Klik tombol keyboard -> Panel emoji tertutup -> Ikon kembali jadi smile
        await tester.tap(find.byTooltip('Keyboard'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Emoji'), findsOneWidget);
        expect(find.byIcon(MekaarIcons.smile), findsOneWidget);
        expect(find.byIcon(MekaarIcons.keyboard), findsNothing);
      },
    );

    testWidgets(
      'Mengetuk TextField saat panel emoji terbuka menutup panel dan mengembalikan ikon ke smile',
      (tester) async {
        await tester.pumpWidget(createHarness());
        await tester.pumpAndSettle();

        // Buka panel emoji
        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Keyboard'), findsOneWidget);

        // Ketuk text field
        await tester.tap(
          find.byKey(const ValueKey('chat_composer_text_field')),
        );
        await tester.pumpAndSettle();

        // Panel emoji harus tertutup dan ikon kembali ke smile
        expect(find.byTooltip('Emoji'), findsOneWidget);
        expect(find.byIcon(MekaarIcons.smile), findsOneWidget);
        expect(find.byIcon(MekaarIcons.keyboard), findsNothing);
      },
    );
  });
}
