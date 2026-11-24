import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/mekaar_bottom_sheet.dart';
import 'package:mekaar_chat/core/widgets/mekaar_custom_duration_picker_sheet.dart';
import 'package:mekaar_chat/features/auth/providers/auto_lock_provider.dart';
import 'package:mekaar_chat/features/auth/services/master_session_bootstrap.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AutoLockTimeout & Notifier Tests', () {
    test('Default timeout adalah 30 detik (AutoLockTimeout.thirtySeconds)', () {
      final notifier = AutoLockTimeoutNotifier();
      expect(notifier.state, AutoLockTimeout.thirtySeconds);
      expect(notifier.state.label, '30 Detik');
      expect(notifier.state.duration, const Duration(seconds: 30));
    });

    test('Mengubah timeout memperbarui state dan menyimpan ke SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AutoLockTimeoutNotifier(prefs);

      await notifier.setTimeout(AutoLockTimeout.oneMinute);
      expect(notifier.state, AutoLockTimeout.oneMinute);
      expect(prefs.getString(AutoLockTimeoutNotifier.prefKey), '1m');

      await notifier.setTimeout(AutoLockTimeout.system);
      expect(notifier.state, AutoLockTimeout.system);
      expect(prefs.getString(AutoLockTimeoutNotifier.prefKey), 'system');

      await notifier.setTimeout(AutoLockTimeout.off);
      expect(notifier.state, AutoLockTimeout.off);
      expect(prefs.getString(AutoLockTimeoutNotifier.prefKey), 'off');
    });

    test('AutoLockTimeout.fromKey mengurai key string dengan tepat dan fallback ke 30s', () {
      expect(AutoLockTimeout.fromKey('system'), AutoLockTimeout.system);
      expect(AutoLockTimeout.fromKey('30s'), AutoLockTimeout.thirtySeconds);
      expect(AutoLockTimeout.fromKey('1m'), AutoLockTimeout.oneMinute);
      expect(AutoLockTimeout.fromKey('5m'), AutoLockTimeout.custom);
      expect(AutoLockTimeout.fromKey('custom'), AutoLockTimeout.custom);
      expect(AutoLockTimeout.fromKey('off'), AutoLockTimeout.off);
      expect(AutoLockTimeout.fromKey('unknown_key'), AutoLockTimeout.thirtySeconds);
      expect(AutoLockTimeout.fromKey(null), AutoLockTimeout.thirtySeconds);
    });

    test('setCustomDuration menyimpan durasi kustom dan memuat ulang via initialized', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AutoLockTimeoutNotifier(prefs);

      await notifier.setCustomDuration(const Duration(minutes: 15));
      expect(notifier.state, AutoLockTimeout.custom);
      expect(notifier.customDuration, const Duration(minutes: 15));
      expect(notifier.enforcedDuration, const Duration(minutes: 15));
      expect(prefs.getString(AutoLockTimeoutNotifier.prefKey), 'custom');
      expect(
        prefs.getInt(AutoLockTimeoutNotifier.customDurationSecondsKey),
        900,
      );

      final reloadedNotifier = AutoLockTimeoutNotifier();
      await reloadedNotifier.initialized;
      expect(reloadedNotifier.state, AutoLockTimeout.custom);
      expect(reloadedNotifier.customDuration, const Duration(minutes: 15));
    });
  });

  group('Private Vault Dialog Title & Legacy Elimination Tests', () {
    testWidgets('showUnlockPasscodeDialog menampilkan judul Verifikasi PIN Master tanpa teks Profil 1', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      PrivateVaultDialogs.showUnlockPasscodeDialog(context, null, 1);
                    },
                    child: const Text('Buka Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Ketuk tombol untuk memunculkan dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Verifikasi: Judul adalah 'Verifikasi PIN Master', BUKAN 'Buka Profil 1'
      expect(find.text('Verifikasi PIN Master'), findsOneWidget);
      expect(find.text('Buka Profil 1'), findsNothing);
      expect(find.text('Profil 1'), findsNothing);

      // Verifikasi: Tombol Batal & Buka
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Buka'), findsOneWidget);
    });
  });

  group('SettingsScreen Auto-Lock UI Integration Tests', () {
    test('SettingsScreen memuat tile navigasi Kunci Otomatis dan BottomSheet handler', () {
      final file = File('lib/features/settings/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('Kunci Otomatis'), isTrue);
      expect(content.contains('autoLockTimeoutProvider'), isTrue);
      expect(content.contains('_showAutoLockBottomSheet'), isTrue);
    });

    testWidgets('Auto-Lock BottomSheet menampilkan seluruh opsi dan memperbarui timeout', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return ElevatedButton(
                    onPressed: () {
                      MekaarBottomSheet.show(
                        context: context,
                        builder: (ctx) {
                          return Consumer(
                            builder: (context, sheetRef, _) {
                              final options = AutoLockTimeout.values;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: options.map((opt) {
                                  return ListTile(
                                    title: Text(opt.label),
                                    onTap: () {
                                      sheetRef.read(autoLockTimeoutProvider.notifier).setTimeout(opt);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      );
                    },
                    child: const Text('Buka Kunci Otomatis'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka BottomSheet
      await tester.tap(find.text('Buka Kunci Otomatis'));
      await tester.pumpAndSettle();

      // Verifikasi seluruh opsi tampil
      expect(find.text('Saat Layar Terkunci'), findsOneWidget);
      expect(find.text('30 Detik'), findsOneWidget);
      expect(find.text('1 Menit'), findsOneWidget);
      expect(find.text('Kustom'), findsOneWidget);
      expect(find.text('Nonaktif (Tanpa Kunci)'), findsOneWidget);

      // Pilih '1 Menit'
      await tester.tap(find.text('1 Menit'));
      await tester.pumpAndSettle();

      // Verifikasi state telah terupdate
      expect(capturedRef.read(autoLockTimeoutProvider), AutoLockTimeout.oneMinute);
    });

    testWidgets('Alur pemilihan Kustom memperbarui durasi, listenable, dan SharedPreferences', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  final notifier = ref.watch(autoLockTimeoutProvider.notifier);
                  return ValueListenableBuilder<Duration>(
                    valueListenable: notifier.customDurationListenable,
                    builder: (ctx, customDuration, _) {
                      final current = ref.watch(autoLockTimeoutProvider);
                      return Column(
                        children: [
                          Text(
                            current == AutoLockTimeout.custom
                                ? 'Kustom (${MekaarCustomDurationPickerSheet.formatDuration(customDuration)})'
                                : current.label,
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final selected =
                                  await MekaarBottomSheet.show<AutoLockTimeout>(
                                context: context,
                                builder: (ctx) {
                                  return Consumer(
                                    builder: (sheetContext, sheetRef, _) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: AutoLockTimeout.values
                                            .map(
                                              (opt) => ListTile(
                                                title: Text(opt.label),
                                                onTap: () =>
                                                    Navigator.pop(ctx, opt),
                                              ),
                                            )
                                            .toList(),
                                      );
                                    },
                                  );
                                },
                              );
                              if (selected == AutoLockTimeout.custom &&
                                  context.mounted) {
                                final picked =
                                    await MekaarCustomDurationPickerSheet.show(
                                  context: context,
                                  title: 'Kustom Kunci Otomatis',
                                  subtitle:
                                      'Pilih durasi waktu sebelum aplikasi terkunci otomatis',
                                  headerIcon: Icons.lock_clock,
                                  units: const [
                                    MekaarDurationUnit.second,
                                    MekaarDurationUnit.minute,
                                    MekaarDurationUnit.hour,
                                  ],
                                  initialDuration: notifier.customDuration,
                                  minFor: (u) =>
                                      u == MekaarDurationUnit.second ? 5 : 1,
                                  maxFor: (u) =>
                                      u == MekaarDurationUnit.hour ? 24 : 59,
                                  quickPresetsFor: (u) =>
                                      u == MekaarDurationUnit.second
                                          ? const [10, 15, 30, 45]
                                          : const [2, 5, 10, 15],
                                  descriptionBuilder: (d) =>
                                      'Durasi: ${MekaarCustomDurationPickerSheet.formatDuration(d)}',
                                );
                                if (picked != null && context.mounted) {
                                  await ref
                                      .read(autoLockTimeoutProvider.notifier)
                                      .setCustomDuration(picked);
                                }
                              }
                            },
                            child: const Text('Pilih Kustom'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih Kustom'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kustom'));
      await tester.pumpAndSettle();

      expect(find.text('Kustom Kunci Otomatis'), findsOneWidget);

      await tester.tap(find.text('Detik').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 Detik'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terapkan Durasi'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(autoLockTimeoutProvider), AutoLockTimeout.custom);
      expect(
        capturedRef.read(autoLockTimeoutProvider.notifier).enforcedDuration,
        const Duration(seconds: 15),
      );
      expect(find.text('Kustom (15 Detik)'), findsOneWidget);
    });

    testWidgets('MasterSessionBootstrap membuka seluruh slot kontak Vault saat sesi Master tanpa PIN (AutoLockTimeout.off)', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return ElevatedButton(
                    onPressed: () async {
                      await MasterSessionBootstrap.prepareSession(
                        ref,
                        isDecoy: false,
                        isDuress: false,
                        reloadLocalRooms: false,
                        triggerPurge: false,
                      );
                    },
                    child: const Text('Bootstrap Master'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedRef.read(unlockedVaultSlotsProvider), isEmpty);
      expect(capturedRef.read(privateVaultUnlockedProvider), isFalse);

      await tester.tap(find.text('Bootstrap Master'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(capturedRef.read(unlockedVaultSlotsProvider), {1, 2, 3});
      expect(capturedRef.read(privateVaultUnlockedProvider), isTrue);
    });
  });
}
