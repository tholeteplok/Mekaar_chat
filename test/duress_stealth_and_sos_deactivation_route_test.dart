import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_canvas.dart';
import 'package:mekaar_chat/core/widgets/mekaar_pin_verification_sheet.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/screens/sos_active_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthRepo extends Fake implements AuthRepository {
  final bool isDuressStatus;
  FakeAuthRepo({this.isDuressStatus = false});

  @override
  Future<bool> validatePIN(String pin) async => pin == '123456';

  @override
  Future<bool> validateDuressPIN(String pin) async => pin == '999999';

  @override
  Future<bool> validateDecoyPIN(String pin) async => false;

  @override
  Future<void> saveUnlockMode(String mode) async {}

  @override
  Future<String> getUnlockMode() async => isDuressStatus ? 'duress' : 'master';

  @override
  Future<void> saveDuressUnlockStatus(bool status) async {}

  @override
  Future<bool> getDuressUnlockStatus() async => isDuressStatus;

  @override
  Future<void> clearPinLockout() async {}
}

class FakeSOSRepo extends Fake implements SOSRepository {
  final SOSSession? session;
  FakeSOSRepo({this.session});

  @override
  Future<SOSSession?> getActiveSOS() async => session;

  @override
  Future<void> endSession(String sessionId, {String reason = 'manual'}) async {}
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(super.repo, AuthState initialState) {
    state = initialState;
  }

  @override
  Future<bool> validatePIN(
    String pin, {
    bool allowDuress = true,
    bool allowDecoy = true,
  }) async {
    return pin == '123456';
  }
}

class FakeSOSNotifier extends SOSNotifier {
  FakeSOSNotifier(super.repo, SOSState initialState) {
    state = initialState;
  }

  @override
  Future<void> endSOS({String reason = 'manual'}) async {
    state = SOSState(status: SOSStatus.idle);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Duress Stealth & SOS Deactivation Route Tests', () {
    final fakeSession = SOSSession(
      id: 'session-1',
      userId: 'user-1',
      status: 'active',
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
      gpsEnabled: true,
    );

    testWidgets('MekaarCanvas: Saat SOS aktif normal (non-duress), latar merah AppColors.sosDeep',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('normal_sos_scope'),
          overrides: [
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                FakeSOSRepo(session: fakeSession),
                SOSState(status: SOSStatus.active, activeSession: fakeSession),
              ),
            ),
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                FakeAuthRepo(isDuressStatus: false),
                AuthState(
                  user: null,
                  profile: Profile(
                    id: 'user-1',
                    username: 'user1',
                    email: 'u@example.com',
                    pinHash: 'hash',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  isPinSet: true,
                  lastUnlockWasDuress: false, // BUKAN DURESS
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: MekaarCanvas(
              flat: true,
              child: Text('Konten Normal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redContainers = tester.widgetList<Container>(find.byType(Container)).where(
            (c) => c.color == AppColors.sosDeep,
          );
      expect(redContainers, isNotEmpty,
          reason: 'SOS normal harus menampilkan kanvas merah AppColors.sosDeep');
    });

    testWidgets('MekaarCanvas: Saat Duress aktif, latar TIDAK BOLEH merah demi stealth & keselamatan',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('duress_sos_scope'),
          overrides: [
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                FakeSOSRepo(session: fakeSession),
                SOSState(status: SOSStatus.active, activeSession: fakeSession),
              ),
            ),
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                FakeAuthRepo(isDuressStatus: true),
                AuthState(
                  user: null,
                  profile: Profile(
                    id: 'user-1',
                    username: 'user1',
                    email: 'u@example.com',
                    pinHash: 'hash',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  isPinSet: true,
                  lastUnlockWasDuress: true, // DURESS AKTIF (STEALTH)
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: MekaarCanvas(
              flat: true,
              child: Text('Konten Normal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stealthRedContainers = tester.widgetList<Container>(find.byType(Container)).where(
            (c) => c.color == AppColors.sosDeep,
          );
      expect(stealthRedContainers, isEmpty,
          reason: 'Saat duress aktif, kanvas merah dilarang muncul demi keselamatan fisik korban');
    });

    testWidgets('SOSActiveScreen: Mematikan SOS pada root route beralih ke AppRoutes.home tanpa black screen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeSessionEnd = SOSSession(
        id: 'session-end-1',
        userId: 'user-1',
        status: 'active',
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
        gpsEnabled: true,
      );

      final fakeSosRepo = FakeSOSRepo(session: fakeSessionEnd);
      final fakeAuthRepo = FakeAuthRepo(isDuressStatus: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(fakeSosRepo),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                fakeSosRepo,
                SOSState(status: SOSStatus.active, activeSession: fakeSessionEnd),
              ),
            ),
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                fakeAuthRepo,
                AuthState(
                  user: null,
                  profile: Profile(
                    id: 'user-1',
                    username: 'user1',
                    email: 'u@example.com',
                    pinHash: 'hash',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  isPinSet: true,
                  lastUnlockWasDuress: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.sosActive,
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.sosActive) {
                return MaterialPageRoute(builder: (_) => const SOSActiveScreen());
              }
              if (settings.name == AppRoutes.home) {
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Home Screen Loaded')),
                );
              }
              return null;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Layar SOS aktif terbuka
      final endBtnFinder = find.text('Nonaktifkan SOS (Perlu PIN)');
      expect(endBtnFinder, findsOneWidget);

      await tester.ensureVisible(endBtnFinder);
      await tester.pumpAndSettle();

      // Ketuk tombol nonaktifkan
      await tester.tap(endBtnFinder);
      await tester.pumpAndSettle();

      // Modal sheet verifikasi PIN terbuka
      final sheetFinder = find.byType(MekaarPinVerificationSheet);
      expect(sheetFinder, findsOneWidget);

      // Selesaikan verifikasi PIN dengan mengembalikan true (PIN valid)
      Navigator.of(tester.element(sheetFinder)).pop(true);
      await tester.pumpAndSettle();

      // Verifikasi: Layar berhasil beralih ke Home Screen dan TIDAK menjadi Black Screen
      expect(find.text('Home Screen Loaded'), findsOneWidget);
    });
  });
}
