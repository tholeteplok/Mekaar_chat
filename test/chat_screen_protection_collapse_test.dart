import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final testProtectionProvider = StateProvider<bool>((ref) => true);

void main() {
  testWidgets('ChatScreen Stack with StackFit.expand never collapses when screen protection turns off', (tester) async {
    final container = ProviderContainer();
    final stackKey = GlobalKey();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Stack(
                key: stackKey,
                fit: StackFit.expand,
                children: [
                  // Layer 0: Wallpaper
                  Positioned.fill(
                    child: Container(color: Colors.blue),
                  ),
                  // Layer 1: Messages
                  Positioned.fill(
                    child: Container(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  // Layer 5: Screen protection floating chip
                  Positioned(
                    top: 50,
                    left: 0,
                    right: 0,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final isEffective = ref.watch(testProtectionProvider);
                        if (!isEffective) return const SizedBox.shrink();
                        return const Center(
                          child: Text('Proteksi ruang aktif'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Initial state: protection is ON
    expect(find.text('Proteksi ruang aktif'), findsOneWidget);
    var renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;
    expect(renderBox.size, const Size(400, 600));

    // Turn OFF protection
    container.read(testProtectionProvider.notifier).state = false;
    await tester.pumpAndSettle();

    // Verify chip is gone
    expect(find.text('Proteksi ruang aktif'), findsNothing);

    // CRITICAL: Verify Stack size has NOT collapsed to Size.zero
    renderBox = stackKey.currentContext!.findRenderObject() as RenderBox;
    expect(renderBox.size, const Size(400, 600));
  });
}
