import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/settings/screens/pin_management_screen.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

class _FakeAuthRepo extends Fake implements AuthRepository {
  @override
  Future<bool> isDecoyEnabled() async => false;

  @override
  Future<bool> isDuressEnabled() async => false;
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({
    required AuthUnlockMode unlockMode,
    required bool isPinSet,
  }) : super(_FakeAuthRepo()) {
    state = AuthState(
      unlockMode: unlockMode,
      isPinSet: isPinSet,
    );
  }

  @override
  Future<bool> isDecoyEnabled() async => false;

  @override
  Future<bool> isDuressEnabled() async => false;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('PinManagementScreen UI & Camouflage Tests', () {
    testWidgets('Mode Master menampilkan 3 kartu PIN lengkap (Master, Tamu, Darurat)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(
                  unlockMode: AuthUnlockMode.master,
                  isPinSet: true,
                )),
          ],
          child: const MaterialApp(
            home: PinManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi judul halaman
      expect(find.text('Manajemen PIN Keamanan'), findsOneWidget);
      expect(find.text('PIN Master, Tamu & Darurat'), findsOneWidget);

      // Verifikasi Kartu PIN Master
      expect(find.text('PIN Master (Utama)'), findsOneWidget);
      expect(find.text('Wajib & Aktif'), findsOneWidget);
      expect(find.text('Ganti PIN Master'), findsOneWidget);

      // Verifikasi Kartu PIN Tamu
      expect(find.text('PIN Tamu (Decoy)'), findsOneWidget);
      expect(find.text('Atur PIN Tamu'), findsOneWidget);

      // Scroll ke bawah untuk melihat Kartu PIN Darurat (karena berada di bawah lipatan)
      await tester.scrollUntilVisible(
        find.text('PIN Darurat (Silent SOS)'),
        100.0,
      );
      await tester.pumpAndSettle();

      expect(find.text('PIN Darurat (Silent SOS)'), findsOneWidget);
      expect(find.text('Atur PIN Darurat'), findsOneWidget);
    });

    testWidgets('Mode Tamu (Decoy) berkamuflase hanya menampilkan 1 kartu tunggal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(
                  unlockMode: AuthUnlockMode.decoy,
                  isPinSet: true,
                )),
          ],
          child: const MaterialApp(
            home: PinManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi kamuflase header
      expect(find.text('PIN Keamanan'), findsOneWidget);
      expect(find.text('Kelola kode akses keamanan'), findsOneWidget);

      // Verifikasi kartu tunggal
      expect(find.text('PIN Keamanan Aplikasi'), findsOneWidget);
      expect(find.text('Ganti PIN Aplikasi'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);

      // Zero-Knowledge: pastikan jejak Master, Tamu, dan SOS tidak muncul sama sekali
      expect(find.text('PIN Master (Utama)'), findsNothing);
      expect(find.text('PIN Tamu (Decoy)'), findsNothing);
      expect(find.text('PIN Darurat (Silent SOS)'), findsNothing);
    });
  });

  group('PrivateContactRepository Multi-Slot Activation without Passcode Tests', () {
    test('Slot 1 selalu aktif secara default', () async {
      final repo = PrivateContactRepository();
      final active = await repo.getActiveSlots();
      expect(active, contains(1));
    });

    test('Mengaktifkan slot 2 menambahkannya ke daftar slot aktif tanpa passcode',
        () async {
      final repo = PrivateContactRepository();
      await repo.activateSlot(2, name: 'Bisnis Rahasia');

      final active = await repo.getActiveSlots();
      expect(active, containsAll([1, 2]));

      final name = await repo.getSlotName(2);
      expect(name, 'Bisnis Rahasia');
    });

    test('Menghapus slot 2 mencabutnya dari daftar slot aktif', () async {
      final repo = PrivateContactRepository();
      await repo.activateSlot(2, name: 'Bisnis Rahasia');
      expect(await repo.getActiveSlots(), contains(2));

      await repo.deleteSlotPasscode(2);
      final activeAfterDelete = await repo.getActiveSlots();
      expect(activeAfterDelete, isNot(contains(2)));
    });
  });

  group('Silent Vaulting State Tests', () {
    test('HiddenContactUserIdsNotifier menyembunyikan kontak ke RAM & storage', () async {
      final containerRef = ProviderContainer();
      addTearDown(containerRef.dispose);

      final notifier = containerRef.read(hiddenContactUserIdsProvider.notifier);
      expect(containerRef.read(hiddenContactUserIdsProvider), isEmpty);

      // Toggle sembunyikan kontak (Silent Vaulting)
      await notifier.toggleHide('contact_123');
      expect(containerRef.read(hiddenContactUserIdsProvider), contains('contact_123'));

      // Memastikan kontak terdaftar di set
      expect(
        containerRef.read(hiddenContactUserIdsProvider).contains('contact_123'),
        isTrue,
      );
    });

    test('HiddenRoomIdsNotifier menyembunyikan obrolan ke RAM & storage', () async {
      final containerRef = ProviderContainer();
      addTearDown(containerRef.dispose);

      final notifier = containerRef.read(hiddenRoomIdsProvider.notifier);
      expect(containerRef.read(hiddenRoomIdsProvider), isEmpty);

      // Toggle sembunyikan obrolan (Silent Vaulting)
      await notifier.toggleHide('room_abc');
      expect(containerRef.read(hiddenRoomIdsProvider), contains('room_abc'));
    });
  });
}
