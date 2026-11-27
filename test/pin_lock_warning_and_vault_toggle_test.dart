import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/data/models/vault_item.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/providers/auto_lock_provider.dart';
import 'package:mekaar_chat/features/chat/providers/vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/vault_screen.dart';
import 'package:mekaar_chat/features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier()
      : super(
          AuthState(
            isPinSet: true,
            unlockMode: AuthUnlockMode.master,
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockVaultNotifier extends StateNotifier<AsyncValue<List<VaultItem>>>
    implements VaultNotifier {
  _MockVaultNotifier(List<VaultItem> items) : super(AsyncValue.data(items));

  @override
  Future<void> loadItems({String? query}) async {}

  @override
  Future<bool> deleteItem(String id) async => true;

  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('VaultPinLockNotifier & DatabaseKeyService Pinless Unlock', () {
    test('Default aktif (true), dapat diubah ke false & dipulihkan dari prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = VaultPinLockNotifier(prefs);
      await notifier.initialized;
      expect(notifier.state, isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool(VaultPinLockNotifier.prefKey), isFalse);

      final reloaded = VaultPinLockNotifier();
      await reloaded.initialized;
      expect(reloaded.state, isFalse);
    });

    test('EphemeralSettingGuard mencegah Guest/Decoy menimpa preferensi persisten', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(VaultPinLockNotifier.prefKey, true);

      final notifier = VaultPinLockNotifier(prefs)
        ..attachEphemeralGuard(() => true);
      await notifier.initialized;

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool(VaultPinLockNotifier.prefKey), isTrue);
    });

    test('DatabaseKeyService menyimpan dan menghapus material unlock Keystore', () async {
      expect(
        await DatabaseKeyService.instance.hasPinlessMasterVaultUnlock(),
        isFalse,
      );

      await DatabaseKeyService.instance.storePinlessMasterVaultUnlock('123456');
      expect(
        await DatabaseKeyService.instance.hasPinlessMasterVaultUnlock(),
        isTrue,
      );

      await DatabaseKeyService.instance.clearPinlessMasterVaultUnlock();
      expect(
        await DatabaseKeyService.instance.hasPinlessMasterVaultUnlock(),
        isFalse,
      );
    });
  });

  group('Peringatan & Konfirmasi PIN Master pada Kunci Otomatis (Off)', () {
    testWidgets(
      'Memilih Nonaktif (Tanpa Kunci) menampilkan dialog peringatan lalu meminta PIN Utama',
      (tester) async {
        late ProviderContainer container;
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _FakeAuthNotifier()),
              autoLockTimeoutProvider.overrideWith(
                (ref) => AutoLockTimeoutNotifier(prefs),
              ),
            ],
            child: MaterialApp(
              theme: MekaarTheme.lightTheme(),
              home: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () =>
                            SettingsScreen.showAutoLockBottomSheet(
                          context,
                          ref,
                        ),
                        child: const Text('Kunci Otomatis'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Buka bottom sheet Kunci Otomatis
        await tester.tap(find.text('Kunci Otomatis'));
        await tester.pumpAndSettle();

        // Pilih Nonaktif (Tanpa Kunci)
        await tester.tap(find.text('Nonaktif (Tanpa Kunci)'));
        await tester.pumpAndSettle();

        // Verifikasi dialog peringatan muncul
        expect(find.text('Nonaktifkan PIN Layar Masuk?'), findsOneWidget);

        // Tekan Tetap Aktif -> timeout harus tetap thirtySeconds
        await tester.tap(find.text('Tetap Aktif'));
        await tester.pumpAndSettle();
        expect(
          container.read(autoLockTimeoutProvider),
          AutoLockTimeout.thirtySeconds,
        );

        // Ulangi dan tekan Lanjutkan -> wajib memunculkan MekaarPinVerificationSheet
        await tester.tap(find.text('Kunci Otomatis'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nonaktif (Tanpa Kunci)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lanjutkan'));
        await tester.pumpAndSettle();

        expect(find.text('Verifikasi PIN Utama'), findsOneWidget);
        expect(
          container.read(autoLockTimeoutProvider),
          AutoLockTimeout.thirtySeconds,
        );
      },
    );
  });

  group('Switch On/Off & Peringatan pada VaultScreen (Brankas Berkas)', () {
    testWidgets(
      'Mematikan switch memunculkan peringatan & PIN Utama; menyalakan kembali langsung meminta PIN Utama',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _FakeAuthNotifier()),
              vaultItemsProvider.overrideWith((ref) => _MockVaultNotifier(const [])),
              vaultPinLockEnabledProvider.overrideWith(
                (ref) => VaultPinLockNotifier(prefs),
              ),
            ],
            child: MaterialApp(
              theme: MekaarTheme.lightTheme(),
              home: const VaultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(const ValueKey('vault_pin_lock_switch'));
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<Switch>(switchFinder).value, isTrue);

        // Tap switch (ON -> OFF)
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(find.text('Nonaktifkan PIN Brankas Berkas?'), findsOneWidget);

        // Batalkan -> tetap aktif
        await tester.tap(find.text('Tetap Terkunci'));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);

        // Tap switch lagi -> Lanjutkan -> muncul sheet verifikasi PIN Utama
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lanjutkan'));
        await tester.pumpAndSettle();

        expect(find.text('Verifikasi PIN Utama'), findsOneWidget);
      },
    );

    testWidgets(
      'Menyalakan kembali switch saat kondisi OFF langsung meminta Verifikasi PIN Utama',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(VaultPinLockNotifier.prefKey, false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _FakeAuthNotifier()),
              vaultItemsProvider.overrideWith((ref) => _MockVaultNotifier(const [])),
              vaultPinLockEnabledProvider.overrideWith(
                (ref) => VaultPinLockNotifier(prefs),
              ),
            ],
            child: MaterialApp(
              theme: MekaarTheme.lightTheme(),
              home: const VaultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(const ValueKey('vault_pin_lock_switch'));
        expect(tester.widget<Switch>(switchFinder).value, isFalse);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Tidak ada dialog destruktif saat menyalakan kembali, langsung Verifikasi PIN Utama
        expect(find.text('Nonaktifkan PIN Brankas Berkas?'), findsNothing);
        expect(find.text('Verifikasi PIN Utama'), findsOneWidget);
      },
    );
  });
}
