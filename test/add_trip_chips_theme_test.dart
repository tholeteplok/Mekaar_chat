import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/saved_place_model.dart';
import 'package:mekaar_chat/features/settings/providers/trip_provider.dart';
import 'package:mekaar_chat/features/settings/screens/add_trip_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness({required bool isDark}) {
    return ProviderScope(
      overrides: [
        activeGuardiansProvider.overrideWith((ref) => Future.value(<Guardian>[])),
        savedPlacesProvider.overrideWith((ref) => Future.value(<String, SavedPlace>{})),
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: const AddTripScreen(),
      ),
    );
  }

  group('AddTripScreen ChoiceChip & FilterChip Theme Alignment Tests', () {
    testWidgets('ChoiceChip titik asal memiliki teks putih saat terpilih dan solid primary', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHarness(isDark: true));
      await tester.pump(const Duration(milliseconds: 200));

      final chipFinder = find.byWidgetPredicate(
        (w) => w is ChoiceChip && w.label is Text && ((w.label as Text).data?.contains('Lokasi Saat Ini') ?? false),
      );
      expect(chipFinder, findsOneWidget);

      final choiceChip = tester.widget<ChoiceChip>(chipFinder);
      expect(choiceChip.selected, isTrue);
      expect(choiceChip.labelStyle?.color, equals(Colors.white));
      expect(choiceChip.labelStyle?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('FilterChip hari aktif memiliki centang & teks putih saat terpilih', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHarness(isDark: true));
      await tester.pump(const Duration(milliseconds: 200));

      // Secara default Senin (1) s.d. Jumat (5) terpilih
      final seninChipFinder = find.widgetWithText(FilterChip, 'Sen');
      expect(seninChipFinder, findsOneWidget);

      final filterChip = tester.widget<FilterChip>(seninChipFinder);
      expect(filterChip.selected, isTrue);
      expect(filterChip.checkmarkColor, equals(Colors.white));
      expect(filterChip.labelStyle?.color, equals(Colors.white));
      expect(filterChip.labelStyle?.fontWeight, equals(FontWeight.bold));
    });
  });
}
