import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_detail_screen.dart';

class _FakeAuthRepo extends Fake implements AuthRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthUnlockMode mode) : super(_FakeAuthRepo()) {
    state = AuthState(unlockMode: mode, isPinSet: true);
  }
}

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'owner-1';
}

class _SpyGuardianRepo extends Fake implements GuardianRepository {
  int updateDurationCallCount = 0;
  DateTime? lastUpdatedExpiresAt = DateTime.utc(1970);
  bool lastReactivateIfExpired = false;

  @override
  Future<List<Guardian>> getMyGuardians() async => const <Guardian>[];

  @override
  Future<void> updateGuardianDuration(
    String guardianRelationId, {
    required DateTime? expiresAt,
    bool reactivateIfExpired = false,
  }) async {
    updateDurationCallCount++;
    lastUpdatedExpiresAt = expiresAt;
    lastReactivateIfExpired = reactivateIfExpired;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('T27 — Manajemen Masa Aktif Guardian', () {
    test('Guardian model isPermanent, daysRemaining, dan isExpired mengevaluasi null vs tanggal dengan akurat', () {
      final nowUtc = DateTime.now().toUtc();
      final permanent = Guardian(
        id: 'g-perm',
        ownerId: 'owner-1',
        guardianId: 'guard-1',
        name: 'Budi',
        email: 'budi@example.com',
        permissions: const {'gps': true, 'mic': false, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: null,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      expect(permanent.isPermanent, isTrue);
      expect(permanent.isExpired, isFalse);

      final expiringSoon = Guardian(
        id: 'g-soon',
        ownerId: 'owner-1',
        guardianId: 'guard-2',
        name: 'Sari',
        email: 'sari@example.com',
        permissions: const {'gps': true, 'mic': false, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: nowUtc.add(const Duration(days: 1, hours: 2)),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      expect(expiringSoon.isPermanent, isFalse);
      expect(expiringSoon.isExpired, isFalse);
      expect(expiringSoon.daysRemaining, 1);

      final expired = Guardian(
        id: 'g-exp',
        ownerId: 'owner-1',
        guardianId: 'guard-3',
        name: 'Tono',
        email: 'tono@example.com',
        permissions: const {'gps': true, 'mic': false, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: nowUtc.subtract(const Duration(hours: 2)),
        createdAt: nowUtc.subtract(const Duration(days: 10)),
        updatedAt: nowUtc.subtract(const Duration(days: 10)),
      );
      expect(expired.isPermanent, isFalse);
      expect(expired.isExpired, isTrue);
      expect(expired.daysRemaining, 0);
    });

    Widget buildDetailScreen({
      required Guardian guardian,
      required _SpyGuardianRepo spyRepo,
      AuthUnlockMode mode = AuthUnlockMode.master,
    }) {
      return ProviderScope(
        key: ValueKey('guardian_detail_${mode.name}_${guardian.id}'),
        overrides: [
          supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
          authProvider.overrideWith((ref) => _FakeAuthNotifier(mode)),
          guardianRepositoryProvider.overrideWithValue(spyRepo),
        ],
        child: MaterialApp(
          home: GuardianDetailScreen(guardian: guardian),
        ),
      );
    }

    testWidgets('GuardianDetailScreen menampilkan Masa Aktif, peringatan konsekuensi Permanen, dan memperbarui durasi', (
      tester,
    ) async {
      final nowUtc = DateTime.now().toUtc();
      final guardian = Guardian(
        id: 'rel-1',
        ownerId: 'owner-1',
        guardianId: 'guard-1',
        name: 'mekaar',
        email: 'mekaar@example.com',
        permissions: const {'gps': true, 'mic': false, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: nowUtc.add(const Duration(days: 1, hours: 6)),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final spyRepo = _SpyGuardianRepo();
      await tester.pumpWidget(
        buildDetailScreen(guardian: guardian, spyRepo: spyRepo),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('guardian_duration_tile')), findsOneWidget);
      expect(find.text('Masa Aktif Guardian'), findsOneWidget);

      // Buka Bottom Sheet pemilihan durasi
      await tester.ensureVisible(
        find.byKey(const ValueKey('guardian_duration_tile')),
      );
      await tester.tap(find.byKey(const ValueKey('guardian_duration_tile')));
      await tester.pumpAndSettle();

      expect(find.text('7 Hari dari Sekarang'), findsOneWidget);
      expect(find.text('30 Hari dari Sekarang'), findsOneWidget);
      expect(find.text('90 Hari (3 Bulan)'), findsOneWidget);
      expect(find.text('Permanen (Tanpa Batas)'), findsOneWidget);
      expect(find.text('Pilih Tanggal Berakhir...'), findsOneWidget);

      // Pilih Permanen -> wajib memunculkan dialog peringatan konsekuensi dulu
      await tester.tap(find.text('Permanen (Tanpa Batas)'));
      await tester.pumpAndSettle();

      expect(find.text('Jadikan Guardian Permanen?'), findsOneWidget);
      expect(
        find.textContaining('tidak akan memiliki tanggal kedaluwarsa otomatis'),
        findsOneWidget,
      );

      // Batalkan dulu -> tidak boleh memanggil updateGuardianDuration
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(spyRepo.updateDurationCallCount, 0);

      // Buka lagi & konfirmasi Permanen
      await tester.tap(find.byKey(const ValueKey('guardian_duration_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Permanen (Tanpa Batas)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap Jadikan Permanen'));
      await tester.pumpAndSettle();

      expect(spyRepo.updateDurationCallCount, 1);
      expect(spyRepo.lastUpdatedExpiresAt, isNull);
      expect(find.text('Guardian Aktif • Permanen'), findsOneWidget);

      // Ubah ke 30 Hari dari Sekarang
      await tester.tap(find.byKey(const ValueKey('guardian_duration_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 Hari dari Sekarang'));
      await tester.pumpAndSettle();

      expect(spyRepo.updateDurationCallCount, 2);
      expect(spyRepo.lastUpdatedExpiresAt, isNotNull);
      expect(
        spyRepo.lastUpdatedExpiresAt!.difference(DateTime.now().toUtc()).inDays,
        greaterThanOrEqualTo(29),
      );
    });

    testWidgets('Mode Tamu mengubah masa aktif hanya di RAM tanpa memanggil repository server', (
      tester,
    ) async {
      final nowUtc = DateTime.now().toUtc();
      final guardian = Guardian(
        id: 'rel-guest-1',
        ownerId: 'owner-1',
        guardianId: 'guard-2',
        name: 'Ibu',
        email: 'ibu@example.com',
        permissions: const {'gps': true, 'mic': false, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: nowUtc.add(const Duration(days: 1, hours: 6)),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final spyRepo = _SpyGuardianRepo();
      await tester.pumpWidget(
        buildDetailScreen(
          guardian: guardian,
          spyRepo: spyRepo,
          mode: AuthUnlockMode.decoy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('guardian_duration_tile')),
      );
      await tester.tap(find.byKey(const ValueKey('guardian_duration_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 Hari dari Sekarang'));
      await tester.pumpAndSettle();

      expect(spyRepo.updateDurationCallCount, 0);
    });

    testWidgets('Judul seksi pada GuardianDetailScreen rata kiri menggunakan MekaarSectionHeader', (
      tester,
    ) async {
      final nowUtc = DateTime.now().toUtc();
      final guardian = Guardian(
        id: 'rel-align-1',
        ownerId: 'owner-1',
        guardianId: 'guard-3',
        name: 'Andi',
        email: 'andi@example.com',
        permissions: const {'gps': true, 'mic': true, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        expiresAt: nowUtc.add(const Duration(days: 7)),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final spyRepo = _SpyGuardianRepo();
      await tester.pumpWidget(
        buildDetailScreen(guardian: guardian, spyRepo: spyRepo),
      );
      await tester.pumpAndSettle();

      for (final title in [
        'Masa Aktif Hubungan',
        'Izin Keamanan (Hanya Aktif Saat SOS)',
        'Tindakan',
      ]) {
        final finder = find.text(title);
        expect(finder, findsOneWidget);
        expect(tester.getTopLeft(finder).dx, 20.0);
      }
    });
  });
}
