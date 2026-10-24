import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';

void main() {
  group('Color Tokens & Adaptive Contrast Tests (Batch 5)', () {
    testWidgets('outgoingTextOf returns dark text on bright bubble colors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Bright background colors (luminance > 0.5)
              final textOnYellow = MekaarColors.outgoingTextOf(
                context,
                Colors.yellow,
              );
              final textOnWhite = MekaarColors.outgoingTextOf(
                context,
                Colors.white,
              );
              final textOnLime = MekaarColors.outgoingTextOf(
                context,
                Colors.lime,
              );

              expect(textOnYellow, AppColors.darkBlue);
              expect(textOnWhite, AppColors.darkBlue);
              expect(textOnLime, AppColors.darkBlue);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('outgoingTextOf returns white text on dark bubble colors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Dark background colors (luminance <= 0.5)
              final defaultText = MekaarColors.outgoingTextOf(context);
              final textOnBlue = MekaarColors.outgoingTextOf(
                context,
                AppColors.blue,
              );
              final textOnDarkBlue = MekaarColors.outgoingTextOf(
                context,
                AppColors.darkBlue,
              );
              final textOnBlack = MekaarColors.outgoingTextOf(
                context,
                Colors.black,
              );

              expect(defaultText, Colors.white);
              expect(textOnBlue, Colors.white);
              expect(textOnDarkBlue, Colors.white);
              expect(textOnBlack, Colors.white);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('textMutedOf and textSecondaryOf are context-aware',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              final lightSecondary = MekaarColors.textSecondaryOf(context);
              final lightMuted = MekaarColors.textMutedOf(context);

              expect(lightSecondary, MekaarColors.textSecondaryLight);
              expect(
                lightMuted,
                MekaarColors.textSecondaryLight.withValues(alpha: 0.72),
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
