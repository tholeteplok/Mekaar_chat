import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/animations.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier() : super(FakeAuthRepository()) {
    state = AuthState(isLoading: false, isPinSet: true);
  }
}

class FakeAuthRepository extends Fake implements AuthRepository {}

class _FakeSosNotifier extends StateNotifier<SOSState> implements SOSNotifier {
  _FakeSosNotifier() : super(SOSState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PinScreen Keypad Tactile PressableScale Tests', () {
    testWidgets(
      'Tombol keypad PIN menggunakan PressableScale tanpa InkResponse/InkWell kotak dan mengecil saat ditekan',
      (tester) async {
        tester.view.physicalSize = const Size(540, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _MockAuthNotifier()),
              sosProvider.overrideWith((ref) => _FakeSosNotifier()),
            ],
            child: const MaterialApp(
              home: PinScreen(isSetup: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pastikan tidak ada InkResponse atau InkWell pada tombol numpad (bebas efek tekan kotak)
        expect(find.byType(InkResponse), findsNothing);

        // Setiap tombol angka (0-9), Lupa/empty, & backspace menggunakan PressableScale
        expect(find.byType(PressableScale), findsAtLeastNWidgets(11));

        final digit5Finder = find.text('5');
        expect(digit5Finder, findsOneWidget);

        // Tekan dan tahan tombol '5' -> AnimatedScale harus mengecil ke 0.92
        final pressableOf5 = find.ancestor(
          of: digit5Finder,
          matching: find.byType(PressableScale),
        );
        expect(pressableOf5, findsOneWidget);

        final gesture = await tester.startGesture(tester.getCenter(digit5Finder));
        await tester.pump(const Duration(milliseconds: 50));

        final animatedScaleDuringPress = tester.widget<AnimatedScale>(
          find.descendant(
            of: pressableOf5,
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(animatedScaleDuringPress.scale, equals(0.92));

        // Lepas sentuhan -> skala kembali ke 1.0
        await gesture.up();
        await tester.pumpAndSettle();

        final animatedScaleAfterRelease = tester.widget<AnimatedScale>(
          find.descendant(
            of: pressableOf5,
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(animatedScaleAfterRelease.scale, equals(1.0));
      },
    );
  });
}
