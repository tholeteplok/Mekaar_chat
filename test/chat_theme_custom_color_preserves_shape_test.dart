import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';

void main() {
  group('Custom Color Preserves Bubble Shapes & Tails Test', () {
    testWidgets('Custom outgoing color preserves Mecha Chamfer shape & tail',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              const pref = ChatThemePreference(
                preset: ChatThemePreset.custom,
                bubbleStyle: ChatBubbleStyle.mechaChamfer,
                useCustomBubbleColors: true,
                outgoingColor1: '#FF0055', // Custom Crimson Pink
                outgoingColor2: '#AA0033',
              );

              final spec = ChatPresetResolver.getBubbleSpec(
                pref,
                context,
                isMe: true,
              );

              // Verification: Shape and Tail must remain Mecha Chamfer!
              expect(spec.shapeType, equals(BubbleShapeType.mechaChamfered));
              expect(spec.tailType, equals(BubbleTailType.mechaChamfer));
              // Color must be the custom color!
              expect(spec.backgroundColor, equals(const Color(0xFFFF0055)));
              expect(spec.gradient, isNotNull);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Custom incoming color preserves Comic Box shape, beak & 2px border',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              const pref = ChatThemePreference(
                preset: ChatThemePreset.custom,
                bubbleStyle: ChatBubbleStyle.playfulOutlined,
                useCustomBubbleColors: true,
                incomingColor1: '#00AAFF', // Custom Ocean Blue
              );

              final spec = ChatPresetResolver.getBubbleSpec(
                pref,
                context,
                isMe: false,
              );

              // Verification: Comic box shape, beak tail and border remain!
              expect(spec.shapeType, equals(BubbleShapeType.comicBox));
              expect(spec.tailType, equals(BubbleTailType.comicBeakBottom));
              expect(spec.border, isNotNull);
              expect(spec.border!.top.width, equals(2.0));
              expect(spec.backgroundColor, equals(const Color(0xFF00AAFF)));

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Custom color preserves Pixel Craft 3D bevel and stepped voxel shape',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              const pref = ChatThemePreference(
                preset: ChatThemePreset.custom,
                bubbleStyle: ChatBubbleStyle.pixelGardenStyle,
                useCustomBubbleColors: true,
                outgoingColor1: '#228833',
              );

              final spec = ChatPresetResolver.getBubbleSpec(
                pref,
                context,
                isMe: true,
              );

              expect(spec.shapeType, equals(BubbleShapeType.pixelSteppedVoxel));
              expect(spec.voxelBevel, isNotNull);
              expect(spec.backgroundColor, equals(const Color(0xFF228833)));

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Custom color preserves Neuro UI neumorphic soft shape and deboss',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              const pref = ChatThemePreference(
                preset: ChatThemePreset.custom,
                bubbleStyle: ChatBubbleStyle.neumorphicSoft,
                useCustomBubbleColors: true,
                outgoingColor1: '#334455',
              );

              final spec = ChatPresetResolver.getBubbleSpec(
                pref,
                context,
                isMe: true,
              );

              expect(spec.shapeType, equals(BubbleShapeType.neuroClay));
              expect(spec.tailType, equals(BubbleTailType.neuroNotchBottom));
              expect(spec.hasInsetDeboss, isTrue);
              expect(spec.backgroundColor, equals(const Color(0xFF334455)));

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
