import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/widgets/mekaar_banner.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_detail_screen.dart';

class FakeGuardianRepository extends Fake implements GuardianRepository {
  @override
  Future<void> updatePermissions(
    String guardianRelationId, {
    required Map<String, bool> permissions,
    required String storageOption,
  }) async {}

  @override
  Future<List<Guardian>> getMyGuardians() async => [];
}

void main() {
  group('GuardianDetailScreen Clean Storage Options & Zero-Knowledge Banner Tests', () {
    final dummyGuardian = Guardian(
      id: 'g-123',
      ownerId: 'user-1',
      guardianId: 'user-2',
      name: 'Budi Darma',
      email: 'budi@example.com',
      permissions: {'gps': true, 'mic': false, 'video': false},
      storageOption: 'stream_only',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Menampilkan MekaarBanner transmisi langsung dan membersihkan opsi placeholder', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
          ],
          child: MaterialApp(
            home: GuardianDetailScreen(guardian: dummyGuardian),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verifikasi header bagian
      expect(find.text('INFORMASI TRANSMISI & PRIVASI'), findsOneWidget);
      expect(find.text('OPSI PENYIMPANAN REKAMAN'), findsNothing);

      // 2. Verifikasi MekaarBanner Zero-Knowledge muncul
      expect(find.byType(MekaarBanner), findsOneWidget);
      expect(find.text('Transmisi Langsung (Zero-Knowledge)'), findsOneWidget);
      expect(
        find.textContaining('Audio dan video SOS hanya disiarkan langsung'),
        findsOneWidget,
      );

      // 3. Verifikasi opsi placeholder lama sudah bersih
      expect(find.text('Server Terenkripsi'), findsNothing);
      expect(find.text('Drive Pribadi Saya'), findsNothing);
      expect(find.text('Drive + Tautan Sementara'), findsNothing);
      expect(find.text('File langsung ke Google Drive/iCloud Anda.'), findsNothing);
    });
  });
}
