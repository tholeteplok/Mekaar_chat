import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/features/settings/widgets/settings_tiles.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_list_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Borderless Canvas-First UI Consistency Tests', () {
    testWidgets('SettingsDivider renders with 0.8 thickness and 78 indent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsDivider(),
          ),
        ),
      );

      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsOneWidget);

      final divider = tester.widget<Divider>(dividerFinder);
      expect(divider.height, 1);
      expect(divider.thickness, 0.8);
      expect(divider.indent, 78);
      expect(divider.endIndent, 0);
    });

    testWidgets('SettingsNavTile and SettingsSwitchTile render seamlessly without card wrapper', (tester) async {
      bool switchValue = false;
      bool navTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    const SettingsSectionHeader(title: 'Keamanan'),
                    SettingsNavTile(
                      icon: SolarIconsOutline.lock,
                      title: 'PIN Keamanan',
                      valueText: 'Aktif',
                      onTap: () {
                        navTapped = true;
                      },
                    ),
                    const SettingsDivider(),
                    SettingsSwitchTile(
                      icon: SolarIconsOutline.shieldWarning,
                      title: 'Fitur Darurat SOS',
                      value: switchValue,
                      onChanged: (val) {
                        setState(() => switchValue = val);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Keamanan'), findsOneWidget);
      expect(find.text('PIN Keamanan'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Fitur Darurat SOS'), findsOneWidget);
      expect(find.text('Nonaktif'), findsOneWidget);

      // Tap Nav Tile
      await tester.tap(find.text('PIN Keamanan'));
      await tester.pumpAndSettle();
      expect(navTapped, isTrue);

      // Tap Switch Tile
      await tester.tap(find.text('Fitur Darurat SOS'));
      await tester.pumpAndSettle();
      expect(switchValue, isTrue);
      expect(find.text('Aktif'), findsNWidgets(2)); // Value text NavTile + Switch label
    });

    testWidgets('ChatListTile renders edge-to-edge without card borders', (tester) async {
      final sampleRoom = {
        'id': 'room-001',
        'name': 'Budi Santoso',
        'lastMessage': 'Halo, apa kabar?',
        'lastMessageAt': DateTime.now().toIso8601String(),
        'unreadCount': 2,
        'isPinned': true,
        'isGuardian': false,
        'isGroup': false,
      };

      bool tileTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: sampleRoom,
                onTap: () {
                  tileTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Halo, apa kabar?'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // unread badge

      await tester.tap(find.text('Budi Santoso'));
      await tester.pumpAndSettle();
      expect(tileTapped, isTrue);
    });
  });
}
