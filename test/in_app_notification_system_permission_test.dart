import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/widgets/mekaar_in_app_notification_banner.dart';
import 'package:mekaar_chat/data/services/alarm_service.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.overrideNotificationsEnabled = null;
    MekaarInAppNotificationBanner.dismiss();
  });

  tearDown(() {
    NotificationService.overrideNotificationsEnabled = null;
    MekaarInAppNotificationBanner.dismiss();
  });

  Widget buildTestHarness({Widget? child}) {
    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      home: Scaffold(body: child ?? const Center(child: Text('Home Test'))),
    );
  }

  group('In-App Notification & System Permission Tests', () {
    testWidgets(
      'Saat notifikasi OS dinonaktifkan & app di foreground: suara mati, in-app banner muncul',
      (tester) async {
        NotificationService.overrideNotificationsEnabled = false;

        await tester.pumpWidget(buildTestHarness());
        await tester.pumpAndSettle();

        await NotificationService.showMessageNotification(
          title: 'Ahmad',
          body: 'Halo, kamu di mana?',
          roomId: 'room_ahmad_1',
          route: NotificationRoute(
            type: NotificationRouteType.message,
            roomId: 'room_ahmad_1',
            chatName: 'Ahmad',
            chatAvatar: 'A',
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Suara AlarmService TIDAK diputar (hening)
        expect(AlarmService.isPlaying, isFalse);

        // 2. Banner in-app muncul di layar atas
        expect(find.byType(MekaarInAppNotificationBanner), findsOneWidget);
        expect(find.text('Ahmad'), findsOneWidget);
        expect(find.text('Halo, kamu di mana?'), findsOneWidget);

        // Bersihkan timer auto-dismiss
        MekaarInAppNotificationBanner.dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Saat notifikasi OS dinonaktifkan & app di-minimize (background): hening total (zero alert)',
      (tester) async {
        NotificationService.overrideNotificationsEnabled = false;

        await tester.pumpWidget(buildTestHarness());
        await tester.pumpAndSettle();

        // Simulasikan app di-minimize / background
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        await NotificationService.showMessageNotification(
          title: 'Ahmad',
          body: 'Pesan rahasia',
          roomId: 'room_ahmad_1',
        );

        await tester.pump();

        // 1. Suara mati
        expect(AlarmService.isPlaying, isFalse);

        // 2. Banner in-app TIDAK boleh muncul sama sekali saat minimize
        expect(find.byType(MekaarInAppNotificationBanner), findsNothing);
      },
    );

    testWidgets(
      'Men-tap banner in-app memicu callback navigasi dan menutup banner',
      (tester) async {
        NotificationService.overrideNotificationsEnabled = false;

        NotificationRoute? tappedRoute;
        NotificationService.initialize(
          onNotificationTap: (route) {
            tappedRoute = route;
          },
        );

        await tester.pumpWidget(buildTestHarness());
        await tester.pumpAndSettle();

        final expectedRoute = NotificationRoute(
          type: NotificationRouteType.message,
          roomId: 'room_target_99',
          chatName: 'Siti',
          chatAvatar: 'S',
        );

        await NotificationService.showMessageNotification(
          title: 'Siti',
          body: 'Sampai ketemu nanti',
          roomId: 'room_target_99',
          route: expectedRoute,
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MekaarInAppNotificationBanner), findsOneWidget);

        // Tap banner
        await tester.tap(find.byType(MekaarInAppNotificationBanner));
        await tester.pumpAndSettle();

        // Callback tap navigasi terpanggil dengan data route yang tepat
        expect(tappedRoute, isNotNull);
        expect(tappedRoute?.roomId, equals('room_target_99'));

        // Banner langsung ter-dismiss
        expect(find.byType(MekaarInAppNotificationBanner), findsNothing);
      },
    );

    testWidgets(
      'Swipe-up gesture menutup in-app notification banner seketika',
      (tester) async {
        NotificationService.overrideNotificationsEnabled = false;

        await tester.pumpWidget(buildTestHarness());
        await tester.pumpAndSettle();

        await NotificationService.showMessageNotification(
          title: 'Rian',
          body: 'Halo bro',
          roomId: 'room_rian',
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(MekaarInAppNotificationBanner), findsOneWidget);

        // Swipe up dismissible
        await tester.drag(
          find.byType(MekaarInAppNotificationBanner),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MekaarInAppNotificationBanner), findsNothing);
      },
    );

    testWidgets(
      'In-app banner konsisten menghormati masking Private Contact Vault dan Stealth Preview',
      (tester) async {
        NotificationService.overrideNotificationsEnabled = false;

        await tester.pumpWidget(buildTestHarness());
        await tester.pumpAndSettle();

        // Skenario pesan masked dari Private Vault
        await NotificationService.showMessageNotification(
          title: 'MEKAAR',
          body: '••••••••',
          roomId: 'vault_room_1',
          route: NotificationRoute(
            type: NotificationRouteType.message,
            roomId: 'vault_room_1',
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Judul dan isi tetap terlindungi tanpa membocorkan privasi
        expect(find.text('MEKAAR'), findsOneWidget);
        expect(find.text('••••••••'), findsOneWidget);

        // Bersihkan timer auto-dismiss
        MekaarInAppNotificationBanner.dismiss();
        await tester.pumpAndSettle();
      },
    );
  });
}
