import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';

class MockSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'test_user_id';
}

class FakeAuthRepository extends Fake implements AuthRepository {
  bool pinSet = true;

  @override
  Future<bool> isPINSet() async => pinSet;

  @override
  Future<Map<String, dynamic>> getPinLockout() async => {'attempts': 0, 'lockedUntil': null};

  @override
  Future<String> getUnlockMode() async => 'master';

  @override
  Future<Profile?> getCachedProfile(String userId) async => null;

  @override
  Future<bool> validatePIN(String pin) async => pin == '123456';
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(super.repo, AuthState initialState) {
    state = initialState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fast Synchronous PIN Status & Cache Tests', () {
    test('isPINSet mengembalikan true seketika jika has_pin_set ada di SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'has_pin_set': true,
        'has_pin_set_test_user_id': true,
      });

      final mockSupabase = MockSupabaseService();
      final authRepo = AuthRepository(mockSupabase);

      final isSet = await authRepo.isPINSet();
      expect(isSet, isTrue);
    });

    test('isPINSet mendeteksi pin_hash dari cached_profile dan mem-backfill fast cache', () async {
      final dummyProfile = Profile(
        id: 'test_user_id',
        username: 'andi_test',
        email: 'andi@test.com',
        pinHash: 'argon2id:hash_dummy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'cached_profile_test_user_id': jsonEncode(dummyProfile.toJson()),
      });

      final mockSupabase = MockSupabaseService();
      final authRepo = AuthRepository(mockSupabase);

      final isSet = await authRepo.isPINSet();
      expect(isSet, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_pin_set_test_user_id'), isTrue);
      expect(prefs.getBool('has_pin_set'), isTrue);
    });

    test('isPINSet mengembalikan false jika tidak ada data cache dan profil kosong', () async {
      SharedPreferences.setMockInitialValues({
        'has_pin_set_test_user_id': false,
        'has_pin_set': false,
      });

      final mockSupabase = MockSupabaseService();
      final authRepo = AuthRepository(mockSupabase);

      final isSet = await authRepo.isPINSet();
      expect(isSet, isFalse);
    });
  });

  group('PinScreen Self-Healing Guard Tests', () {
    testWidgets('PinScreen(isSetup: true) otomatis beralih ke mode validasi jika akun sudah ber-PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository()..pinSet = true;
      final fakeAuthState = AuthState(
        isPinSet: true,
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authProvider.overrideWith((ref) => FakeAuthNotifier(fakeAuthRepo, fakeAuthState)),
          ],
          child: const MaterialApp(
            home: PinScreen(isSetup: true),
          ),
        ),
      );

      // Tunggu post-frame callback dan self-healing async check
      await tester.pumpAndSettle();

      // Verifikasi: Layar harus otomatis menjadi mode validasi (1x input), BUKAN mode buat PIN baru
      expect(find.text('Masukkan PIN 6 digit Anda untuk masuk.'), findsOneWidget);
      expect(find.text('Buat PIN 6 digit untuk mengamankan aplikasi.'), findsNothing);
    });

    testWidgets('PinScreen(isSetup: true) tetap mode setup jika akun memang belum memiliki PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository()..pinSet = false;
      final fakeAuthState = AuthState(
        isPinSet: false,
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authProvider.overrideWith((ref) => FakeAuthNotifier(fakeAuthRepo, fakeAuthState)),
          ],
          child: const MaterialApp(
            home: PinScreen(isSetup: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi: Untuk user baru tanpa PIN, tetap tampil instruksi buat PIN (2x input)
      expect(find.text('Buat PIN 6 digit untuk mengamankan aplikasi.'), findsOneWidget);
      expect(find.text('Masukkan PIN 6 digit Anda untuk masuk.'), findsNothing);
    });
  });
}
