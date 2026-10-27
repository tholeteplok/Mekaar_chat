import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/settings/screens/profile_screen.dart';
import 'package:solar_icons/solar_icons.dart';

class MockAuthRepository extends Fake implements AuthRepository {
  @override
  Future<bool> validatePIN(String pin) async => true;
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(AuthState initial) : super(MockAuthRepository()) {
    state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = Profile(
    id: 'user-uuid-123',
    username: 'alex_safe',
    email: 'alex@example.com',
    pinHash: 'hashed_pin',
    fullName: 'Alex Pratama',
    displayName: 'Alex',
    bio: 'Selalu waspada dan aman',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget createWidget({Profile? profile}) {
    final authState = AuthState(
      profile: profile ?? testProfile,
      isPinSet: true,
      unlockMode: AuthUnlockMode.master,
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(authState)),
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  group('Permanent Username Lock & Read-Only Profile Tests', () {
    testWidgets('Renders username as static text with lock icon', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Memastikan label Username dan nilai @alex_safe tampil
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('@alex_safe'), findsOneWidget);

      // Memastikan ikon gembok SolarIconsOutline.lock tampil untuk field statis (Username & Email)
      expect(find.byIcon(SolarIconsOutline.lock), findsAtLeastNWidgets(2));
    });

    testWidgets('Tapping username row displays permanent lock informative snackbar', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap pada baris username
      await tester.tap(find.text('@alex_safe'));
      await tester.pumpAndSettle();

      // Memverifikasi snackbar info muncul memberi edukasi kepada pengguna
      expect(
        find.text('Username bersifat permanen dan tidak dapat diubah.'),
        findsOneWidget,
      );
    });

    testWidgets('Username row has no pen icon or editable TextField', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Nama dan Bio memiliki tombol ubah (SolarIconsOutline.pen)
      final penIcons = find.byIcon(SolarIconsOutline.pen);
      expect(penIcons, findsNWidgets(2)); // Display name & Bio

      // Tidak ada TextField yang terbuka secara default
      expect(find.byType(TextField), findsNothing);
    });
  });
}
