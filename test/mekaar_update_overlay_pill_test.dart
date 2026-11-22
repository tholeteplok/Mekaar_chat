import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/providers/update_download_provider.dart';
import 'package:mekaar_chat/core/widgets/mekaar_floating_update_pill.dart';
import 'package:mekaar_chat/core/widgets/mekaar_update_overlay.dart';
import 'package:mekaar_chat/data/services/update_service.dart';
import 'package:mekaar_chat/features/chat/providers/call_state_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class _FakeUpdateService extends Fake implements UpdateService {}

class _TestUpdateDownloadController extends UpdateDownloadController {
  _TestUpdateDownloadController(super.updateService, UpdateDownloadState initial) {
    state = initial;
  }
}

class _FakeSosNotifier extends StateNotifier<SOSState> implements SOSNotifier {
  _FakeSosNotifier() : super(SOSState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const sampleUpdateInfo = AppUpdateInfo(
    hasUpdate: true,
    currentVersion: '2.6.4',
    latestVersion: '2.6.5',
    releaseName: 'Mekaar v2.6.5',
    releaseNotes: 'Perbaikan stabilitas dan keamanan.',
    downloadUrl: 'https://example.com/mekaar.apk',
    htmlUrl: 'https://example.com/release',
    downloadSizeBytes: 1024 * 1024 * 25,
    formattedSize: '25.0 MB',
  );

  Widget buildTestApp(UpdateDownloadState initialDownloadState) {
    return ProviderScope(
      overrides: [
        activeCallIdProvider.overrideWith((ref) => null),
        sosProvider.overrideWith((ref) => _FakeSosNotifier()),
        updateDownloadProvider.overrideWith(
          (ref) => _TestUpdateDownloadController(
            _FakeUpdateService(),
            initialDownloadState,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: AppNavigator.navigatorKey,
        builder: (context, child) {
          return MekaarUpdateOverlay(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Scaffold(
          body: Center(child: Text('Home Content')),
        ),
      ),
    );
  }

  group('MekaarUpdateOverlay & MekaarFloatingUpdatePill Tap Navigation Tests', () {
    testWidgets(
      'Tap widget lingkaran saat unduhan BELUM selesai (downloading, minimized) membuka bottom sheet progres',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const UpdateDownloadState(
              status: UpdateDownloadStatus.downloading,
              info: sampleUpdateInfo,
              progress: 0.45,
              receivedBytes: 450,
              totalBytes: 1000,
              isMinimized: true,
              statusMessage: 'Mengunduh 45%...',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(MekaarFloatingUpdatePill), findsOneWidget);
        expect(find.text('45%'), findsOneWidget);

        await tester.tap(find.byType(MekaarFloatingUpdatePill));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Mengunduh Pembaruan'), findsOneWidget);
        expect(find.text('Mengunduh 45%...'), findsOneWidget);
      },
    );

    testWidgets(
      'Tap widget lingkaran saat unduhan SUDAH selesai (completed, minimized) membuka bottom sheet instalasi',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const UpdateDownloadState(
              status: UpdateDownloadStatus.completed,
              info: sampleUpdateInfo,
              progress: 1.0,
              receivedBytes: 1000,
              totalBytes: 1000,
              downloadedFilePath: '/tmp/mekaar.apk',
              isMinimized: true,
              hasAutoPrompted: true,
              statusMessage: 'Pembaruan siap dipasang',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(MekaarFloatingUpdatePill), findsOneWidget);
        expect(find.byIcon(SolarIconsBold.fileCheck), findsOneWidget);

        await tester.tap(find.byType(MekaarFloatingUpdatePill));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Pembaruan Siap Dipasang!'), findsOneWidget);
        expect(find.text('Pasang Sekarang'), findsOneWidget);
      },
    );
  });
}
