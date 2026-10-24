import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';

void main() {
  group('7 Chat Theme Presets Day & Night Resolution Tests', () {
    final presets = [
      ChatThemePreference.mekaar,
      ChatThemePreference.comic,
      ChatThemePreference.neuro,
      ChatThemePreference.mecha,
      ChatThemePreference.pixel,
      ChatThemePreference.candy,
      ChatThemePreference.eco,
    ];

    testWidgets('All 7 presets resolve valid BubbleSpec in Light and Dark modes',
        (tester) async {
      for (final isDark in [false, true]) {
        final brightness = isDark ? Brightness.dark : Brightness.light;
        final themeData = ThemeData(brightness: brightness);

        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            home: Builder(
              builder: (context) {
                for (final pref in presets) {
                  // Outgoing bubble
                  final outgoing = ChatPresetResolver.getBubbleSpec(
                    pref,
                    context,
                    isMe: true,
                  );
                  expect(outgoing.textColor, isNotNull);
                  expect(
                    outgoing.backgroundColor != Colors.transparent ||
                        outgoing.gradient != null,
                    isTrue,
                    reason: '${pref.preset} outgoing has color or gradient',
                  );

                  // Incoming bubble
                  final incoming = ChatPresetResolver.getBubbleSpec(
                    pref,
                    context,
                    isMe: false,
                  );
                  expect(incoming.textColor, isNotNull);
                  expect(
                    incoming.backgroundColor != Colors.transparent ||
                        incoming.gradient != null,
                    isTrue,
                    reason: '${pref.preset} incoming has color or gradient',
                  );

                  // RoomThemeSpec
                  final roomSpec =
                      ChatPresetResolver.getRoomThemeSpec(pref, context);
                  expect(roomSpec.primaryAccentColor, isNotNull);
                  expect(roomSpec.textColor, isNotNull);
                  expect(roomSpec.iconColor, isNotNull);

                  // Wallpaper Widget Build
                  final wallpaper =
                      ChatPresetResolver.buildWallpaper(pref, context);
                  expect(wallpaper, isNotNull);
                }
                return const SizedBox();
              },
            ),
          ),
        );
      }
    });

    testWidgets('Mecha Style resolves correctly and replaces Glassmorphism',
        (tester) async {
      expect(ChatThemePreference.mecha.bubbleStyle,
          equals(ChatBubbleStyle.mechaChamfer));
      expect(ChatThemePreference.glass.bubbleStyle,
          equals(ChatBubbleStyle.mechaChamfer));
      expect(ChatThemePreference.mecha.wallpaperType,
          equals(WallpaperType.mechaBlueprintGrid));
      expect(ChatThemePreference.glass.wallpaperType,
          equals(WallpaperType.mechaBlueprintGrid));

      final themeData = ThemeData(brightness: Brightness.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: Builder(
            builder: (context) {
              // Mecha preset
              final mechaOutgoing = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.mecha,
                context,
                isMe: true,
              );
              expect(mechaOutgoing.border, isNotNull);

              // Legacy glass alias resolves to mecha
              final glassOutgoing = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.glass,
                context,
                isMe: true,
              );
              expect(glassOutgoing.border, isNotNull);
              expect(glassOutgoing.backgroundColor,
                  equals(mechaOutgoing.backgroundColor));

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Wallpaper painters render properly without layout exception',
        (tester) async {
      for (final pref in presets) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 600,
                child: Stack(
                  children: [
                    Builder(
                      builder: (context) =>
                          ChatPresetResolver.buildWallpaper(pref, context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
