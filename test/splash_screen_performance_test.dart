import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/models/device_lost_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/device_lost_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/screens/splash_screen.dart';
import 'package:mekaar_chat/features/sos/providers/device_lost_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';

class _FakeAuthRepository implements AuthRepository {
  final bool isPinSetResult;

  _FakeAuthRepository({this.isPinSetResult = true});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName;
    if (memberName == #getPinLockout) {
      return Future.value(<String, dynamic>{
        'attempts': 0,
        'lockedUntil': null,
      });
    }
    if (memberName == #getUnlockMode) {
      return Future.value('master');
    }
    if (memberName == #isPINSet) {
      return Future.value(isPinSetResult);
    }
    if (memberName == #getDuressUnlockStatus) {
      return Future.value(false);
    }
    if (memberName == #is2faVerified) {
      return Future.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  final Completer<void> _completer = Completer<void>();

  _MockAuthNotifier(super.initialState) {
    _completer.complete();
  }

  @override
  Future<void> get initializationComplete => _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeviceLostRepository implements DeviceLostRepository {
  final bool isLocked;
  _FakeDeviceLostRepository({this.isLocked = false});

  @override
  Future<DeviceLostState> getDeviceLostState() async {
    return DeviceLostState(isLocked: isLocked);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSosRepository implements SOSRepository {
  final SOSSession? activeSession;
  final Duration delay;

  _FakeSosRepository({this.activeSession, this.delay = Duration.zero});

  @override
  Future<SOSSession?> getActiveSOS() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return activeSession;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen Concurrency & Performance Optimization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'is_pin_lock_enabled': true});
    });

    Widget createHarness({
      required AuthState initialAuthState,
      AuthRepository? authRepo,
      DeviceLostRepository? deviceLostRepo,
      SOSRepository? sosRepo,
    }) {
      final fakeAuthRepo = authRepo ?? _FakeAuthRepository();
      final fakeDeviceLostRepo = deviceLostRepo ?? _FakeDeviceLostRepository();
      final fakeSosRepo = sosRepo ?? _FakeSosRepository();

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          deviceLostRepositoryProvider.overrideWithValue(fakeDeviceLostRepo),
          sosRepositoryProvider.overrideWithValue(fakeSosRepo),
          authProvider.overrideWith(
            (ref) => _MockAuthNotifier(initialAuthState),
          ),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.pin: (_) => const Scaffold(body: Text('PIN Screen')),
            AppRoutes.home: (_) => const Scaffold(body: Text('Home Screen')),
            AppRoutes.onboarding: (_) =>
                const Scaffold(body: Text('Onboarding Screen')),
            AppRoutes.sosActive: (_) =>
                const Scaffold(body: Text('SOS Active Screen')),
            AppRoutes.deviceLostLock: (_) =>
                const Scaffold(body: Text('Device Lost Screen')),
          },
        ),
      );
    }

    testWidgets(
      'SplashScreen bertransisi ke PIN Screen jika user telah login & PIN aktif',
      (tester) async {
        final authState = AuthState(
          user: const User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
          profile: Profile(
            id: 'test-user-id',
            username: 'testuser',
            email: 'test@mekaar.id',
            pinHash: 'hash',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          isPinSet: true,
        );

        await tester.pumpWidget(
          createHarness(
            initialAuthState: authState,
            authRepo: _FakeAuthRepository(isPinSetResult: true),
          ),
        );

        // Sebelum 500ms -> SplashScreen masih aktif
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(SplashScreen), findsOneWidget);

        // Setelah 500ms + pre-nav checks selesai -> Navigasi ke PIN Screen
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('PIN Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'SplashScreen bertransisi ke Onboarding jika tidak ada sesi user',
      (tester) async {
        await tester.pumpWidget(
          createHarness(initialAuthState: AuthState(user: null)),
        );

        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Onboarding Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'SplashScreen memprioritaskan DeviceLostLock jika perangkat terkunci',
      (tester) async {
        final authState = AuthState(
          user: const User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
          profile: Profile(
            id: 'test-user-id',
            username: 'testuser',
            email: 'test@mekaar.id',
            pinHash: 'hash',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          isPinSet: true,
        );

        await tester.pumpWidget(
          createHarness(
            initialAuthState: authState,
            deviceLostRepo: _FakeDeviceLostRepository(isLocked: true),
          ),
        );

        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Device Lost Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'SplashScreen memprioritaskan rute SOS Active jika activeSos ditemukan',
      (tester) async {
        final authState = AuthState(
          user: const User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
          profile: Profile(
            id: 'test-user-id',
            username: 'testuser',
            email: 'test@mekaar.id',
            pinHash: 'hash',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          isPinSet: true,
        );

        final dummySos = SOSSession(
          id: 'sos-active-123',
          userId: 'test-user-id',
          startedAt: DateTime.now(),
          status: 'active',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createHarness(
            initialAuthState: authState,
            sosRepo: _FakeSosRepository(activeSession: dummySos),
          ),
        );

        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('SOS Active Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Active SOS network check yang lambat (>600ms) tidak membekukan splash screen (timeout fallback)',
      (tester) async {
        final authState = AuthState(
          user: const User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
          profile: Profile(
            id: 'test-user-id',
            username: 'testuser',
            email: 'test@mekaar.id',
            pinHash: 'hash',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          isPinSet: true,
        );

        // Simulasikan network lag 5 detik pada getActiveSOS
        await tester.pumpWidget(
          createHarness(
            initialAuthState: authState,
            sosRepo: _FakeSosRepository(delay: const Duration(seconds: 5)),
          ),
        );

        // Pada detik ke-1.2 (500ms presentation + 600ms timeout), splash screen harus sudah fail-forward
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Berhasil lanjut ke PIN Screen tanpa menunggu 5 detik
        expect(find.text('PIN Screen'), findsOneWidget);

        // Habiskan sisa timer mock di fake async agar tidak ada timer pending
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
