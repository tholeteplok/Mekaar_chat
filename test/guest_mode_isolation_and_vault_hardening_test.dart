import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/core/services/guest_session_guard.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/providers/auto_lock_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/settings/providers/privacy_provider.dart';
import 'package:mekaar_chat/features/settings/screens/profile_screen.dart';

class _MockAuthRepo extends Fake implements AuthRepository {
  String masterPin = '111111';
  String? guestPin = '222222';
  String? duressPin = '999999';
  String savedMode = 'master';
  bool signOutCalled = false;

  @override
  Future<bool> validatePIN(String pin) async => pin == masterPin;

  @override
  Future<bool> validateDecoyPIN(String pin) async => pin == guestPin;

  @override
  Future<bool> validateDuressPIN(String pin) async => pin == duressPin;

  @override
  Future<void> setPIN(String pin) async {
    masterPin = pin;
  }

  @override
  Future<void> setDecoyPIN(String pin) async {
    guestPin = pin;
  }

  @override
  Future<void> setDuressPIN(String pin) async {
    duressPin = pin;
  }

  @override
  Future<void> saveUnlockMode(String mode) async {
    savedMode = mode;
  }

  @override
  Future<void> saveDuressUnlockStatus(bool status) async {
    savedMode = status ? 'duress' : 'master';
  }

  @override
  Future<void> clearPinLockout() async {}

  @override
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {}

  @override
  Future<DateTime> getServerTime() async => DateTime.utc(2026, 11, 19);

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  bool logoutCalled = false;

  _FakeAuthNotifier(super.repo, AuthState initialState) {
    state = initialState;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

class _FakeGuardianRepo extends Fake implements GuardianRepository {
  @override
  Future<List<Guardian>> getMyGuardians() async => const <Guardian>[];

  @override
  Future<List<Guardian>> getWhoAddedMe() async => const <Guardian>[];
}

class _FixedGuardiansNotifier extends GuardiansNotifier {
  _FixedGuardiansNotifier(List<Guardian> initial, Ref ref)
      : super(_FakeGuardianRepo(), ref) {
    state = initial;
  }

  @override
  Future<void> refreshGuardians() async {}
}

class _FixedWhoAddedMeNotifier extends WhoAddedMeNotifier {
  _FixedWhoAddedMeNotifier(List<Guardian> initial, Ref ref)
      : super(_FakeGuardianRepo(), ref) {
    state = initial;
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    DatabaseKeyService.instance.lockVault();
  });

  group('T16 — Isolasi Brankas 3-Jalur (VaultSpace) & Mode-Bound PIN', () {
    test('VaultSpace memiliki nama DB dan direktori fisik yang terpisah total', () {
      expect(VaultSpace.master.dbFileName, 'mekaar_vault.db');
      expect(VaultSpace.guest.dbFileName, 'mekaar_vault_guest.db');
      expect(VaultSpace.duress.dbFileName, 'mekaar_vault_decoy.db');

      expect(VaultSpace.master.folderName, 'master');
      expect(VaultSpace.guest.folderName, 'guest');
      expect(VaultSpace.duress.folderName, 'duress');
    });

    test('deriveVaultKey menghasilkan 3 kunci berbeda untuk Master, Guest, dan Duress dengan PIN sama', () async {
      const samePin = '123456';
      final keyService = DatabaseKeyService.instance;

      final masterKey = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.master,
      );
      final guestKey = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.guest,
      );
      final duressKey = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.duress,
      );

      expect(masterKey.length, 64);
      expect(guestKey.length, 64);
      expect(duressKey.length, 64);
      expect(masterKey, isNot(equals(guestKey)));
      expect(masterKey, isNot(equals(duressKey)));
      expect(guestKey, isNot(equals(duressKey)));

      final legacyMaster = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.master,
        forceLegacy: true,
      );
      final legacyGuest = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.guest,
        forceLegacy: true,
      );
      final legacyDuress = await keyService.deriveVaultKey(
        samePin,
        space: VaultSpace.duress,
        forceLegacy: true,
      );
      expect({legacyMaster, legacyGuest, legacyDuress}.length, 3);
    });

    test('setActiveVaultKey melacak ruang aktif tanpa tertukar dan lockVault mereset ke master', () async {
      final keyService = DatabaseKeyService.instance;

      keyService.setActiveVaultKey('guest-key', space: VaultSpace.guest);
      expect(keyService.activeVaultSpace, VaultSpace.guest);
      expect(keyService.isVaultGuest, isTrue);
      expect(keyService.isVaultDuress, isFalse);

      await keyService.lockVault();
      expect(keyService.activeVaultKey, isNull);
      expect(keyService.activeVaultSpace, VaultSpace.master);
      expect(keyService.isVaultGuest, isFalse);
      expect(keyService.isVaultDuress, isFalse);
    });

    test('verifyActiveSessionPin hanya menerima PIN sesi aktif tanpa eskalasi unlockMode', () async {
      final repo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Masuk sebagai Tamu (Decoy)
      expect(await notifier.validatePIN('222222'), isTrue);
      expect(container.read(authProvider).unlockMode, AuthUnlockMode.decoy);

      // Master & Duress PIN wajib ditolak pada verifikasi terikat sesi
      expect(await notifier.verifyActiveSessionPin('111111'), isFalse);
      expect(await notifier.verifyActiveSessionPin('999999'), isFalse);
      expect(container.read(authProvider).unlockMode, AuthUnlockMode.decoy);

      // Guest PIN diterima dan sesi tetap di Mode Tamu
      expect(await notifier.verifyActiveSessionPin('222222'), isTrue);
      expect(container.read(authProvider).unlockMode, AuthUnlockMode.decoy);
    });

    test('Honeypot Guest updateActivePin menolak bentrok dengan Master/Duress secara netral dan Duress tidak bisa menimpa PIN', () async {
      final repo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Masuk Mode Tamu
      await notifier.validatePIN('222222');

      // Percobaan bentrok ke Master PIN
      expect(await notifier.updateActivePin('111111'), isFalse);
      final masterErr = container.read(authProvider).error ?? '';
      expect(masterErr.toLowerCase(), isNot(contains('master')));
      expect(masterErr.toLowerCase(), isNot(contains('utama')));
      expect(repo.guestPin, '222222');

      // Percobaan bentrok ke Duress PIN
      expect(await notifier.updateActivePin('999999'), isFalse);
      final duressErr = container.read(authProvider).error ?? '';
      expect(duressErr.toLowerCase(), isNot(contains('darurat')));
      expect(repo.guestPin, '222222');

      // PIN baru unik berhasil mengubah hanya Guest PIN
      expect(await notifier.updateActivePin('444444'), isTrue);
      expect(repo.guestPin, '444444');
      expect(repo.masterPin, '111111');
      expect(repo.duressPin, '999999');

      // Masuk Mode Duress -> updateActivePin harus ditolak tanpa menimpa Guest/Master
      await notifier.validatePIN('999999');
      expect(await notifier.updateActivePin('555555'), isFalse);
      expect(repo.guestPin, '444444');
      expect(repo.masterPin, '111111');
    });
  });

  group('T19 — Filter Guardian Non-Vault di Mode Tamu & Duress', () {
    final nowUtc = DateTime.utc(2026, 11, 19);
    final futureUtc = DateTime.utc(2026, 12, 19);

    final publicGuardian = Guardian(
      id: 'rel-public',
      ownerId: 'me',
      guardianId: 'user-public',
      name: 'Ibu',
      email: 'ibu@example.com',
      permissions: const {'gps': true, 'mic': false, 'video': false},
      storageOption: 'stream_only',
      status: 'active',
      expiresAt: futureUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    final vaultedGuardian = Guardian(
      id: 'rel-secret',
      ownerId: 'me',
      guardianId: 'user-secret',
      name: 'Kontak Rahasia',
      email: 'rahasia@example.com',
      permissions: const {'gps': true, 'mic': true, 'video': true},
      storageOption: 'stream_only',
      status: 'active',
      expiresAt: futureUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    final incomingPublicPending = Guardian(
      id: 'in-public',
      ownerId: 'user-public',
      guardianId: 'me',
      name: 'Ibu',
      email: 'ibu@example.com',
      permissions: const {'gps': true, 'mic': false, 'video': false},
      storageOption: 'stream_only',
      status: 'pending',
      expiresAt: futureUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    final incomingSecretPending = Guardian(
      id: 'in-secret',
      ownerId: 'user-secret',
      guardianId: 'me',
      name: 'Kontak Rahasia',
      email: 'rahasia@example.com',
      permissions: const {'gps': true, 'mic': true, 'video': false},
      storageOption: 'stream_only',
      status: 'pending',
      expiresAt: futureUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    ProviderContainer buildGuardianContainer(AuthUnlockMode mode) {
      final repo = _MockAuthRepo();
      return ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              repo,
              AuthState(unlockMode: mode, isPinSet: true),
            ),
          ),
          cloakedContactUserIdsProvider.overrideWithValue({'user-secret'}),
          guardianProvider.overrideWith(
            (ref) => _FixedGuardiansNotifier(
              [publicGuardian, vaultedGuardian],
              ref,
            ),
          ),
          whoAddedMeProvider.overrideWith(
            (ref) => _FixedWhoAddedMeNotifier(
              [incomingPublicPending, incomingSecretPending],
              ref,
            ),
          ),
        ],
      );
    }

    test('Mode Master menampilkan semua Guardian; Tamu hanya non-vault; Duress kosong total', () {
      final masterContainer = buildGuardianContainer(AuthUnlockMode.master);
      addTearDown(masterContainer.dispose);
      expect(masterContainer.read(visibleMyGuardiansProvider), hasLength(2));
      expect(masterContainer.read(visibleWhoAddedMeProvider), hasLength(2));
      expect(masterContainer.read(pendingIncomingGuardianCountProvider), 2);

      final guestContainer = buildGuardianContainer(AuthUnlockMode.decoy);
      addTearDown(guestContainer.dispose);
      final guestMy = guestContainer.read(visibleMyGuardiansProvider);
      final guestWho = guestContainer.read(visibleWhoAddedMeProvider);
      expect(guestMy.map((g) => g.guardianId).toList(), ['user-public']);
      expect(guestWho.map((g) => g.ownerId).toList(), ['user-public']);
      expect(guestContainer.read(pendingIncomingGuardianCountProvider), 1);

      final duressContainer = buildGuardianContainer(AuthUnlockMode.duress);
      addTearDown(duressContainer.dispose);
      expect(duressContainer.read(visibleMyGuardiansProvider), isEmpty);
      expect(duressContainer.read(visibleWhoAddedMeProvider), isEmpty);
      expect(duressContainer.read(pendingIncomingGuardianCountProvider), 0);
    });
  });

  group('T20 — Ephemeral Settings Lapis 1 & Safe Silent Close Lapis 3', () {
    test('Toggle pengaturan di Mode Tamu hanya hidup di RAM, menegakkan nilai Master, dan pulih saat restore', () async {
      SharedPreferences.setMockInitialValues({
        AutoLockTimeoutNotifier.prefKey: '30s',
        'is_screenshot_blocked': true,
        StealthChatPreviewNotifier.key: true,
        'is_notification_masked': true,
      });

      final repo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              repo,
              AuthState(unlockMode: AuthUnlockMode.decoy, isPinSet: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pastikan seluruh notifier telah memuat nilai awal dari SharedPreferences
      container.read(autoLockTimeoutProvider);
      container.read(screenshotBlockProvider);
      container.read(stealthChatPreviewProvider);
      container.read(notificationMaskingProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Tamu mengubah pengaturan di UI
      await container
          .read(autoLockTimeoutProvider.notifier)
          .setTimeout(AutoLockTimeout.off);
      await container.read(screenshotBlockProvider.notifier).toggle(false);
      await container.read(stealthChatPreviewProvider.notifier).setEnabled(false);
      await container.read(notificationMaskingProvider.notifier).setEnabled(false);

      // Tampilan RAM berubah agar tamu tidak curiga
      expect(container.read(autoLockTimeoutProvider), AutoLockTimeout.off);
      expect(container.read(screenshotBlockProvider), isFalse);
      expect(container.read(stealthChatPreviewProvider), isFalse);
      expect(container.read(notificationMaskingProvider), isFalse);

      // Nilai keamanan aktif tetap menegakkan konfigurasi Master
      expect(
        container.read(autoLockTimeoutProvider.notifier).enforcedTimeout,
        AutoLockTimeout.thirtySeconds,
      );
      expect(
        container.read(notificationMaskingProvider.notifier).enforcedValue,
        isTrue,
      );

      // Disk persisten SharedPreferences tetap bersih tidak berubah
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AutoLockTimeoutNotifier.prefKey), '30s');
      expect(prefs.getBool('is_screenshot_blocked'), isTrue);
      expect(prefs.getBool(StealthChatPreviewNotifier.key), isTrue);
      expect(prefs.getBool('is_notification_masked'), isTrue);

      // Restore memulihkan seluruh state RAM kembali ke milik Master
      await GuestSessionGuard.restoreMasterPreferences(container);
      expect(container.read(autoLockTimeoutProvider), AutoLockTimeout.thirtySeconds);
      expect(container.read(screenshotBlockProvider), isTrue);
      expect(container.read(stealthChatPreviewProvider), isTrue);
      expect(container.read(notificationMaskingProvider), isTrue);
    });

    testWidgets('Logout di ProfileScreen pada Mode Tamu memicu Safe Silent Close tanpa logout akun', (
      tester,
    ) async {
      final originalExit = GuestSessionGuard.exitAppCallback;
      final originalDelay = GuestSessionGuard.silentCloseDelay;
      var exitCallCount = 0;

      GuestSessionGuard.silentCloseDelay = Duration.zero;
      GuestSessionGuard.exitAppCallback = () async {
        exitCallCount++;
      };
      addTearDown(() {
        GuestSessionGuard.exitAppCallback = originalExit;
        GuestSessionGuard.silentCloseDelay = originalDelay;
      });

      final repo = _MockAuthRepo();
      late _FakeAuthNotifier fakeNotifier;
      final profile = Profile(
        id: 'user-owner',
        username: 'pemilik',
        email: 'owner@example.com',
        pinHash: 'hash',
        displayName: 'Pemilik Akun',
        createdAt: DateTime.utc(2026, 11, 19),
        updatedAt: DateTime.utc(2026, 11, 19),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith(
              (ref) => fakeNotifier = _FakeAuthNotifier(
                repo,
                AuthState(
                  profile: profile,
                  isPinSet: true,
                  unlockMode: AuthUnlockMode.decoy,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ketuk ikon Logout di header Profil
      await tester.tap(find.byIcon(SolarIconsOutline.logout));
      await tester.pumpAndSettle();

      expect(find.text('Keluar Aplikasi?'), findsOneWidget);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(exitCallCount, 1);
      expect(repo.signOutCalled, isFalse);
      expect(fakeNotifier.logoutCalled, isFalse);
    });
  });
}
