import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_list_screen.dart';

class FakeGuardianRepository extends Fake implements GuardianRepository {
  @override
  Future<List<Guardian>> getMyGuardians() async => [];

  @override
  Future<List<Guardian>> getWhoAddedMe() async => [];
}

void main() {
  group('Standardisasi Header Tab Guardian & Physics TabBarView', () {
    testWidgets('Header menggunakan MekaarTabHeader dengan judul Guardian tanpa subtitle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
          ],
          child: const MaterialApp(
            home: GuardianListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan MekaarTabHeader ditemukan
      final headerFinder = find.byType(MekaarTabHeader);
      expect(headerFinder, findsOneWidget);

      final tabHeader = tester.widget<MekaarTabHeader>(headerFinder);
      expect(tabHeader.title, 'Guardian');
      expect(tabHeader.subtitle, isNull);

      // Pastikan teks judul 'Guardian' muncul di layar
      expect(find.text('Guardian'), findsOneWidget);
      // Pastikan subtitle lama dan judul lama tidak ada
      expect(find.text('Saling menjaga dalam situasi darurat'), findsNothing);
      expect(find.text('Sistem Guardian'), findsNothing);
    });

    testWidgets('TabBarView menggunakan NeverScrollableScrollPhysics untuk mencegah konflik swipe horizontal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
          ],
          child: const MaterialApp(
            home: GuardianListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Temukan TabBarView
      final tabBarViewFinder = find.byType(TabBarView);
      expect(tabBarViewFinder, findsOneWidget);

      final tabBarView = tester.widget<TabBarView>(tabBarViewFinder);
      expect(tabBarView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('Tap pada MekaarSlidingSegmentBar mengubah sub-tab secara benar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
          ],
          child: const MaterialApp(
            home: GuardianListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi segmen 'Dijaga' dan 'Menjaga'
      expect(find.text('Dijaga'), findsOneWidget);
      expect(find.text('Menjaga'), findsOneWidget);

      // Tap 'Menjaga'
      await tester.tap(find.text('Menjaga'));
      await tester.pumpAndSettle();

      // Tab controller terupdate dan physics tetap NeverScrollableScrollPhysics
      final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
      expect(tabBarView.physics, isA<NeverScrollableScrollPhysics>());
      expect(tabBarView.controller?.index, 1);
    });
  });
}
