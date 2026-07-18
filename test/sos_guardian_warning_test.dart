import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_dialog.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';

Guardian _guardian({String status = 'active', DateTime? expiresAt}) {
  final now = DateTime(2026, 7, 18, 12);
  return Guardian(
    id: 'relation-id',
    ownerId: 'owner-id',
    guardianId: 'guardian-id',
    name: 'Guardian Test',
    email: 'guardian@example.com',
    permissions: const {'gps': true, 'mic': false, 'video': false},
    storageOption: 'stream_only',
    status: status,
    expiresAt: expiresAt,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _dialogHost(ValueChanged<bool> onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await MekaarDialog.showNoActiveGuardianWarning(
              context: context,
            );
            onResult(result);
          },
          child: const Text('Buka Peringatan'),
        ),
      ),
    ),
  );
}

void main() {
  group('Guardian aktif', () {
    final now = DateTime(2026, 7, 18, 12);

    test('menerima status active tanpa batas kedaluwarsa', () {
      expect(isGuardianActive(_guardian(), now: now), isTrue);
    });

    test('menerima status active yang belum kedaluwarsa', () {
      final guardian = _guardian(
        expiresAt: now.add(const Duration(minutes: 1)),
      );

      expect(isGuardianActive(guardian, now: now), isTrue);
    });

    test('menolak pending, expired, dan relasi melewati expiresAt', () {
      final guardians = [
        _guardian(status: 'pending'),
        _guardian(status: 'expired'),
        _guardian(expiresAt: now),
        _guardian(expiresAt: now.subtract(const Duration(seconds: 1))),
      ];

      expect(activeGuardiansOf(guardians, now: now), isEmpty);
    });
  });

  group('Dialog SOS tanpa Guardian aktif', () {
    testWidgets('Batal menghasilkan keputusan false', (tester) async {
      bool? result;
      await tester.pumpWidget(_dialogHost((value) => result = value));

      await tester.tap(find.text('Buka Peringatan'));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Guardian Aktif'), findsOneWidget);
      expect(find.text('Tetap Aktifkan SOS'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Belum Ada Guardian Aktif'), findsNothing);
    });

    testWidgets('Tetap Aktifkan SOS menghasilkan keputusan true', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_dialogHost((value) => result = value));

      await tester.tap(find.text('Buka Peringatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap Aktifkan SOS'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('tap di luar tidak menutup dialog atau memberi keputusan', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_dialogHost((value) => result = value));

      await tester.tap(find.text('Buka Peringatan'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Guardian Aktif'), findsOneWidget);
      expect(result, isNull);
    });
  });
}
