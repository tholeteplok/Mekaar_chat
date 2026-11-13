import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/providers/auto_lock_provider.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class FakeAuthRepoForLock extends Fake implements AuthRepository {
  String storedMasterPin = '123456';
  String storedDuressPin = '999999';
  String storedDecoyPin = '888888';

  @override
  Future<bool> isPINSet() async => true;

  @override
  Future<bool> validatePIN(String pin) async => pin == storedMasterPin;

  @override
  Future<bool> validateDuressPIN(String pin) async => pin == storedDuressPin;

  @override
  Future<bool> validateDecoyPIN(String pin) async => pin == storedDecoyPin;

  @override
  Future<void> clearPinLockout() async {}

  @override
  Future<void> saveUnlockMode(String mode) async {}

  @override
  Future<String> getUnlockMode() async => 'master';

  @override
  Future<Map<String, dynamic>> getPinLockout() async => {
        'attempts': 0,
        'lockedUntil': null,
      };
}

class FakeChatRepoForLock extends Fake implements ChatRepository {
  @override
  String? get currentUserId => 'user-1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AutoLockController & Notification Guard Logic', () {
    test('consumePendingRoute returns route for master auth and null for duress/decoy', () {
      final controller = AutoLockController();
      const testRoute = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room-123',
        chatName: 'Teman Rahasia',
      );

      // Daftarkan pending route
      controller.setPendingRoute(testRoute);
      expect(controller.pendingNotificationRoute, equals(testRoute));

      // Jika Duress atau Decoy: harus drop rute (kembalikan null)
      final duressResult = controller.consumePendingRoute(isMasterAuth: false);
      expect(duressResult, isNull);
      expect(controller.pendingNotificationRoute, isNull);

      // Daftarkan kembali dan verifikasi Master PIN berhasil mengonsumsi rute
      controller.setPendingRoute(testRoute);
      final masterResult = controller.consumePendingRoute(isMasterAuth: true);
      expect(masterResult, equals(testRoute));
      expect(controller.pendingNotificationRoute, isNull);
    });

    test('isAppLockedWithContainer correctly detects locked state when PinScreen is active or timeout exceeded', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(FakeAuthRepoForLock())..state = AuthState(
              user: User(
                id: 'user-1',
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: DateTime.now().toIso8601String(),
              ),
              profile: Profile(
                id: 'user-1',
                username: 'alice',
                email: 'alice@example.com',
                pinHash: 'dummy',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              isPinSet: true,
            ),
          ),
          autoLockTimeoutProvider.overrideWith(
            (ref) => AutoLockTimeoutNotifier()..state = AutoLockTimeout.system,
          ),
        ],
      );

      final controller = AutoLockController();

      // Kasus 1: PinScreen aktif
      controller.markPinScreenActive(true);
      expect(controller.isAppLockedWithContainer(container), isTrue);

      // Kasus 2: PinScreen tidak aktif, tapi app baru saja di-paused dan timeout = system
      controller.markPinScreenActive(false);
      controller.onAppPaused();
      expect(controller.isAppLockedWithContainer(container), isTrue);
    });
  });

  group('Widget Test: Notification Guard Navigation', () {
    testWidgets('Tapping notification while on PinScreen queues route and does NOT bypass to ChatScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuthRepo = FakeAuthRepoForLock();
      final fakeChatRepo = FakeChatRepoForLock();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            chatRepositoryProvider.overrideWithValue(fakeChatRepo),
            authProvider.overrideWith(
              (ref) => AuthNotifier(fakeAuthRepo)..state = AuthState(
                user: User(
                  id: 'user-1',
                  appMetadata: {},
                  userMetadata: {},
                  aud: 'authenticated',
                  createdAt: DateTime.now().toIso8601String(),
                ),
                profile: Profile(
                  id: 'user-1',
                  username: 'alice',
                  email: 'alice@example.com',
                  pinHash: 'dummy',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
                isPinSet: true,
              ),
            ),
          ],
          child: MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            navigatorObservers: [AppNavigator.observer],
            initialRoute: AppRoutes.pin,
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.pin) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const PinScreen(isSetup: false),
                );
              }
              if (settings.name == AppRoutes.chat) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('HALAMAN CHAT TERBUKA')),
                );
              }
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('HOME SCREEN')),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi layar PIN sedang aktif
      expect(find.byType(PinScreen), findsOneWidget);
      expect(AppNavigator.currentRouteName, equals(AppRoutes.pin));

      // Simulasikan notifikasi pesan masuk di-tap saat aplikasi terkunci di PinScreen
      const incomingNotifRoute = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room-secret-999',
        chatName: 'Pesan Rahasia',
      );

      handleNotificationRoute(incomingNotifRoute);
      await tester.pumpAndSettle();

      // VERIFIKASI KEAMANAN: Layar chat TIDAK BOLEH terbuka! Layar PIN wajib tetap tampil!
      expect(find.text('HALAMAN CHAT TERBUKA'), findsNothing);
      expect(find.byType(PinScreen), findsOneWidget);

      // Verifikasi bahwa rute notifikasi berhasil diantrekan secara aman
      final container = ProviderScope.containerOf(AppNavigator.currentContext!, listen: false);
      final autoLockCtrl = container.read(autoLockControllerProvider);
      expect(autoLockCtrl.pendingNotificationRoute, equals(incomingNotifRoute));

      // Simulasikan pengguna berhasil memverifikasi Master PIN dan membuka aplikasi
      autoLockCtrl.markPinScreenActive(false);
      final pending = autoLockCtrl.consumePendingRoute(isMasterAuth: true);
      expect(pending, equals(incomingNotifRoute));
      expect(autoLockCtrl.pendingNotificationRoute, isNull);

      // Pindah ke HomeScreen seperti yang dilakukan PinScreen setelah unlock
      AppNavigator.navigatorKey.currentState!.pushReplacementNamed(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('HOME SCREEN'), findsOneWidget);

      // Setelah tidak terkunci di HomeScreen, jalankan rute yang tertunda
      handleNotificationRoute(pending!);
      await tester.pumpAndSettle();

      // VERIFIKASI KEAMANAN & KEMUDAHAN (SEAMLESS UX):
      // Layar chat terbuka setelah autentikasi sukses
      expect(find.text('HALAMAN CHAT TERBUKA'), findsOneWidget);
    });

    testWidgets('Tapping notification when app is already unlocked opens ChatScreen directly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Reset static state
      AppNavigator.currentRouteName = null;

      final fakeAuthRepo = FakeAuthRepoForLock();
      final fakeChatRepo = FakeChatRepoForLock();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            chatRepositoryProvider.overrideWithValue(fakeChatRepo),
            authProvider.overrideWith(
              (ref) => AuthNotifier(fakeAuthRepo)..state = AuthState(
                user: User(
                  id: 'user-1',
                  appMetadata: {},
                  userMetadata: {},
                  aud: 'authenticated',
                  createdAt: DateTime.now().toIso8601String(),
                ),
                profile: Profile(
                  id: 'user-1',
                  username: 'alice',
                  email: 'alice@example.com',
                  pinHash: 'dummy',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
                isPinSet: true,
              ),
            ),
          ],
          child: MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            navigatorObservers: [AppNavigator.observer],
            initialRoute: AppRoutes.home,
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.chat) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('HALAMAN CHAT TERBUKA')),
                );
              }
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('HOME SCREEN')),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Aplikasi aktif di HomeScreen (tidak terkunci)
      expect(find.text('HOME SCREEN'), findsOneWidget);
      expect(AppNavigator.currentRouteName, equals(AppRoutes.home));

      const incomingNotifRoute = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room-direct-101',
        chatName: 'Pesan Langsung',
      );

      handleNotificationRoute(incomingNotifRoute);
      await tester.pumpAndSettle();

      // Saat tidak terkunci, langsung buka chat
      expect(find.text('HALAMAN CHAT TERBUKA'), findsOneWidget);
    });
  });
}
