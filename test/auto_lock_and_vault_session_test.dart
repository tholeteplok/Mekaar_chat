import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/mekaar_bottom_sheet.dart';
import 'package:mekaar_chat/features/auth/providers/auto_lock_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      expect(AutoLockTimeout.fromKey('5m'), AutoLockTimeout.fiveMinutes);
      expect(AutoLockTimeout.fromKey('off'), AutoLockTimeout.off);
      expect(AutoLockTimeout.fromKey('unknown_key'), AutoLockTimeout.thirtySeconds);
      expect(AutoLockTimeout.fromKey(null), AutoLockTimeout.thirtySeconds);
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
      expect(find.text('5 Menit'), findsOneWidget);
      expect(find.text('Saat Aplikasi Ditutup'), findsOneWidget);

      // Pilih '1 Menit'
      await tester.tap(find.text('1 Menit'));
      await tester.pumpAndSettle();

      // Verifikasi state telah terupdate
      expect(capturedRef.read(autoLockTimeoutProvider), AutoLockTimeout.oneMinute);
    });
  });
}
