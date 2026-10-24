import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/core/widgets/bubbles/themed_bubble_container.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';

void main() {
  group('7 Chat Theme Presets Shapes, Tails & Accents Tests', () {
    final presets = [
      (ChatThemePreference.mekaar, BubbleTailType.swoopTop, BubbleShapeType.roundedPill),
      (ChatThemePreference.comic, BubbleTailType.comicBeakBottom, BubbleShapeType.comicBox),
      (ChatThemePreference.neuro, BubbleTailType.neuroNotchBottom, BubbleShapeType.neuroClay),
      (ChatThemePreference.mecha, BubbleTailType.mechaChamfer, BubbleShapeType.mechaChamfered),
      (ChatThemePreference.pixel, BubbleTailType.pixelVoxelBottom, BubbleShapeType.pixelSteppedVoxel),
      (ChatThemePreference.candy, BubbleTailType.candyTeardropTop, BubbleShapeType.candyRounded),
      (ChatThemePreference.eco, BubbleTailType.solarLeafBottom, BubbleShapeType.solarLeafBox),
    ];

    testWidgets('Every preset resolves exact signature Shape and Tail types',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              for (final (pref, expectedTail, expectedShape) in presets) {
                final outgoing = ChatPresetResolver.getBubbleSpec(pref, context, isMe: true);
                final incoming = ChatPresetResolver.getBubbleSpec(pref, context, isMe: false);

                expect(outgoing.tailType, equals(expectedTail),
                    reason: '${pref.preset} outgoing tailType mismatch');
                expect(outgoing.shapeType, equals(expectedShape),
                    reason: '${pref.preset} outgoing shapeType mismatch');
                expect(incoming.tailType, equals(expectedTail),
                    reason: '${pref.preset} incoming tailType mismatch');
                expect(incoming.shapeType, equals(expectedShape),
                    reason: '${pref.preset} incoming shapeType mismatch');
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Comic Art has 2px black border and hard drop shadow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final spec = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.comic,
                context,
                isMe: true,
              );
              expect(spec.border, isNotNull);
              expect(spec.border!.top.width, equals(2.0));
              expect(spec.border!.top.color, equals(Colors.black));
              expect(spec.boxShadow, isNotNull);
              expect(spec.boxShadow!.first.offset, equals(const Offset(3, 3)));
              expect(spec.boxShadow!.first.blurRadius, equals(0));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Neuro UI sender has inset deboss configuration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              final sender = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.neuro,
                context,
                isMe: true,
              );
              expect(sender.hasInsetDeboss, isTrue);
              expect(sender.debossDarkColor, isNotNull);
              expect(sender.debossLightColor, isNotNull);

              final receiver = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.neuro,
                context,
                isMe: false,
              );
              expect(receiver.hasInsetDeboss, isFalse);
              expect(receiver.boxShadow, isNotNull);
              expect(receiver.boxShadow!.length, greaterThanOrEqualTo(2));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Mecha Style has chamfer shape without laser vertical accent',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              final sender = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.mecha,
                context,
                isMe: true,
              );
              expect(sender.accentVerticalBorderColor, isNull);
              expect(sender.accentVerticalBorderWidth, isNull);
              expect(sender.shapeType, equals(BubbleShapeType.mechaChamfered));
              expect(sender.tailType, equals(BubbleTailType.mechaChamfer));

              final receiver = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.mecha,
                context,
                isMe: false,
              );
              expect(receiver.accentVerticalBorderColor, isNull);
              expect(receiver.accentVerticalBorderWidth, isNull);
              expect(receiver.shapeType, equals(BubbleShapeType.mechaChamfered));
              expect(receiver.tailType, equals(BubbleTailType.mechaChamfer));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Mekaar Core Light Mode sender bubble color is brandBlue (AppColors.blue)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final sender = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.mekaar,
                context,
                isMe: true,
              );
              expect(sender.backgroundColor, equals(AppColors.blue));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Pixel Craft has 3D beveled voxel borders',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final spec = ChatPresetResolver.getBubbleSpec(
                ChatThemePreference.pixel,
                context,
                isMe: true,
              );
              expect(spec.voxelBevel, isNotNull);
              expect(spec.voxelBevel!.highlightColor, isNotNull);
              expect(spec.voxelBevel!.shadowColor, isNotNull);
              expect(spec.voxelBevel!.width, equals(3.0));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('ThemedBubbleContainer renders all 7 presets in Light & Dark modes without exception',
        (tester) async {
      for (final isDark in [false, true]) {
        for (final (pref, _, _) in presets) {
          for (final isMe in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: isDark ? ThemeData.dark() : ThemeData.light(),
                home: Scaffold(
                  body: Center(
                    child: Builder(
                      builder: (context) {
                        final spec = ChatPresetResolver.getBubbleSpec(pref, context, isMe: isMe);
                        return ThemedBubbleContainer(
                          spec: spec,
                          isMe: isMe,
                          child: const Text('Test Chat Bubble Content'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );

            expect(find.byType(ThemedBubbleContainer), findsOneWidget);
            expect(find.byType(CustomPaint), findsWidgets);
            expect(tester.takeException(), isNull);
          }
        }
      }
    });
  });
}
