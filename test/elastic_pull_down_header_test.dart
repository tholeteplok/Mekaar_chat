import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';
import 'package:mekaar_chat/core/widgets/mekaar_header_search_button.dart';
import 'package:mekaar_chat/core/widgets/mekaar_elastic_pull_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MekaarTabHeader SubHeader Search Tests', () {
    testWidgets('Header displays title and action when not searching', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarTabHeader(
              title: 'Obrolan',
              isSearchActive: false,
              isSubHeaderSearch: true,
              pullProgress: 0.0,
              searchController: searchCtrl,
              searchFocusNode: focusNode,
              action: IconButton(
                key: const ValueKey('header_action_btn'),
                icon: const Icon(SolarIconsOutline.magnifier),
                tooltip: 'Cari Obrolan',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Obrolan'), findsOneWidget);
      expect(find.byKey(const ValueKey('header_action_btn')), findsOneWidget);

      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
    });

    testWidgets('Header reveals TextField sub-row when isSearchActive is true', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();
      bool searchClosed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarTabHeader(
              title: 'Obrolan',
              isSearchActive: true,
              isSubHeaderSearch: true,
              pullProgress: 0.0,
              searchController: searchCtrl,
              searchFocusNode: focusNode,
              onSearchClosed: () {
                searchClosed = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sub-header search bar must be present
      expect(find.byType(TextField), findsOneWidget);

      // Cancel button should invoke onSearchClosed
      final cancelBtn = find.text('Batal');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pump();
      expect(searchClosed, isTrue);
    });

    testWidgets('Header reveals TextField during pull-down even if not yet active', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarTabHeader(
              title: 'Obrolan',
              isSearchActive: false,
              isSubHeaderSearch: true,
              pullProgress: 0.6, // Pulling in progress
              searchController: searchCtrl,
              searchFocusNode: focusNode,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MekaarElasticPullScope Gesture & Interaction Tests', () {
    testWidgets('Elastic pull scope triggers pull progress on overscroll', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();
      bool isSearchActive = false;
      double currentProgress = 0.0;
      bool refreshTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MekaarTabHeader(
                      title: 'Mekaar',
                      isSearchActive: isSearchActive,
                      isSubHeaderSearch: true,
                      pullProgress: currentProgress,
                      searchController: searchCtrl,
                      searchFocusNode: focusNode,
                    ),
                    Expanded(
                      child: MekaarElasticPullScope(
                        isSearchActive: isSearchActive,
                        onSearchActiveChanged: (val) {
                          setState(() => isSearchActive = val);
                        },
                        searchController: searchCtrl,
                        searchFocusNode: focusNode,
                        onPullProgressChanged: (p) {
                          setState(() => currentProgress = p);
                        },
                        onRefresh: () async {
                          refreshTriggered = true;
                        },
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: 20,
                          itemBuilder: (context, i) => ListTile(
                            title: Text('Item $i'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(isSearchActive, isFalse);

      // Drag downwards from Item 0 with distance exceeding threshold 1 (55px)
      final firstItem = find.text('Item 0');
      final gesture = await tester.startGesture(tester.getCenter(firstItem));
      // Drag down 95px: exceeds threshold 1 (55px) without reaching threshold 2 (105px)
      await gesture.moveBy(const Offset(0, 95));
      await tester.pump();

      expect(currentProgress, greaterThan(0.0));

      // Release gesture
      await gesture.up();
      await tester.pumpAndSettle();

      // Search bar should now be latched active
      expect(isSearchActive, isTrue);
      expect(find.byType(TextField), findsOneWidget);
      expect(refreshTriggered, isFalse);
    });

    testWidgets('Elastic pull scope triggers onRefresh on deep pull', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();
      bool isSearchActive = false;
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MekaarTabHeader(
                      title: 'Kontak',
                      isSearchActive: isSearchActive,
                      isSubHeaderSearch: true,
                      searchController: searchCtrl,
                      searchFocusNode: focusNode,
                    ),
                    Expanded(
                      child: MekaarElasticPullScope(
                        isSearchActive: isSearchActive,
                        onSearchActiveChanged: (val) {
                          setState(() => isSearchActive = val);
                        },
                        searchController: searchCtrl,
                        searchFocusNode: focusNode,
                        onRefresh: () async {
                          refreshCalled = true;
                        },
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: 15,
                          itemBuilder: (context, i) => ListTile(
                            title: Text('Contact $i'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final firstItem = find.text('Contact 0');
      final gesture = await tester.startGesture(tester.getCenter(firstItem));
      // Deep pull over 260px to reach refresh threshold
      await gesture.moveBy(const Offset(0, 260));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshCalled, isTrue);
      expect(isSearchActive, isTrue);
    });

    testWidgets('Scroll down collapses search bar if empty and not focused', (tester) async {
      final searchCtrl = TextEditingController();
      final focusNode = FocusNode();
      bool isSearchActive = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MekaarTabHeader(
                      title: 'Mekaar',
                      isSearchActive: isSearchActive,
                      isSubHeaderSearch: true,
                      searchController: searchCtrl,
                      searchFocusNode: focusNode,
                    ),
                    Expanded(
                      child: MekaarElasticPullScope(
                        isSearchActive: isSearchActive,
                        onSearchActiveChanged: (val) {
                          setState(() => isSearchActive = val);
                        },
                        searchController: searchCtrl,
                        searchFocusNode: focusNode,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: 30,
                          itemBuilder: (context, i) => ListTile(
                            title: Text('Message $i'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(isSearchActive, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      // Drag upwards (scrolling down content)
      final midItem = find.text('Message 5');
      await tester.drag(midItem, const Offset(0, -120));
      await tester.pumpAndSettle();

      // Should automatically collapse search bar
      expect(isSearchActive, isFalse);
    });
  });

  group('MekaarHeaderSearchButton Choreographed Flight Tests', () {
    testWidgets('Button renders with initial opacity 1.0 and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarHeaderSearchButton(
              isSearchActive: false,
              pullProgress: 0.0,
              onPressed: () => tapped = true,
              tooltip: 'Cari Obrolan',
            ),
          ),
        ),
      );

      expect(find.byType(MekaarHeaderSearchButton), findsOneWidget);
      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(MekaarHeaderSearchButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, 1.0);

      await tester.tap(find.byType(IconButton));
      expect(tapped, isTrue);
    });

    testWidgets('Button translates downward and fades out when pullProgress increases', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarHeaderSearchButton(
              isSearchActive: false,
              pullProgress: 0.5,
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(MekaarHeaderSearchButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, lessThan(1.0));
      expect(opacityWidget.opacity, greaterThan(0.0));
    });

    testWidgets('Button fades to 0.0 and ignores pointer when isSearchActive is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarHeaderSearchButton(
              isSearchActive: true,
              pullProgress: 0.0,
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(MekaarHeaderSearchButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, 0.0);

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(MekaarHeaderSearchButton),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });
  });
}
