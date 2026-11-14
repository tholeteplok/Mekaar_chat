import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/providers/update_download_provider.dart';
import 'package:mekaar_chat/core/widgets/mekaar_floating_update_pill.dart';
import 'package:mekaar_chat/core/widgets/mekaar_update_bottom_sheet.dart';
import 'package:mekaar_chat/core/widgets/mekaar_update_overlay.dart';
import 'package:mekaar_chat/data/services/update_service.dart';
import 'package:solar_icons/solar_icons.dart';

class FakeUpdateDownloadController extends UpdateDownloadController {
  FakeUpdateDownloadController(
    super.updateService, [
    UpdateDownloadState? initial,
  ]) {
    if (initial != null) state = initial;
  }

  void updateState(UpdateDownloadState newState) {
    state = newState;
  }
}

const testInfo = AppUpdateInfo(
  hasUpdate: true,
  currentVersion: '1.0.0',
  latestVersion: '2.0.0',
  releaseName: 'v2.0.0',
  releaseNotes: 'Pembaruan terkini',
  downloadUrl: 'https://example.com/mekaar.apk',
  htmlUrl: 'https://example.com/releases/tag/v2.0.0',
  downloadSizeBytes: 20 * 1024 * 1024,
  formattedSize: '20 MB',
);

void main() {
  group('In-App Updater Circular Minimize & Auto-Minimize Tests', () {
    testWidgets(
      'MekaarFloatingUpdatePill menampilkan circular progress dan persentase di tengah saat mengunduh',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.downloading,
            progress: 0.45,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: MekaarFloatingUpdatePill())),
            ),
          ),
        );

        await tester.pump();

        // Memastikan CircularProgressIndicator ada
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Memastikan teks persentase "45%" tampil di tengah
        expect(find.text('45%'), findsOneWidget);

        // Memastikan dimensi container adalah 50x50 dan berbentuk lingkaran
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MekaarFloatingUpdatePill),
                matching: find.byType(Container),
              )
              .first,
        );
        final boxDecoration = container.decoration as BoxDecoration;
        expect(
          container.constraints?.tighten(width: 50, height: 50).maxWidth,
          equals(50.0),
        );
        expect(boxDecoration.shape, equals(BoxShape.circle));

        // Ikon fileCheck belum muncul saat unduhan belum 100%
        expect(find.byIcon(SolarIconsBold.fileCheck), findsNothing);
      },
    );

    testWidgets(
      'MekaarFloatingUpdatePill bertransisi ke ikon berkas terverifikasi saat unduhan selesai (100%)',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.completed,
            progress: 1.0,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: MekaarFloatingUpdatePill())),
            ),
          ),
        );

        await tester.pump();

        // Persentase teks tidak ada lagi saat selesai
        expect(find.text('100%'), findsNothing);

        // Ikon berkas terverifikasi SolarIconsBold.fileCheck tampil
        expect(find.byIcon(SolarIconsBold.fileCheck), findsOneWidget);
      },
    );

    testWidgets(
      'MekaarFloatingUpdatePill menampilkan ikon jeda saat status paused',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.paused,
            progress: 0.60,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: MekaarFloatingUpdatePill())),
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(SolarIconsBold.pause), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'Tap lingkaran saat unduhan selesai (100%) membuka sheet pasang APK',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.completed,
            progress: 1.0,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: MekaarFloatingUpdatePill())),
            ),
          ),
        );

        await tester.pump();

        // Tap widget lingkaran
        await tester.tap(find.byType(MekaarFloatingUpdatePill));
        await tester.pumpAndSettle();

        // Sheet pasang pembaruan terbuka
        expect(find.text('Pembaruan Siap Dipasang!'), findsOneWidget);
        expect(find.text('Pasang Sekarang'), findsOneWidget);
      },
    );

    testWidgets(
      'Tap lingkaran saat mengunduh membuka sheet progress dan memicu maximize',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.downloading,
            progress: 0.50,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: MekaarFloatingUpdatePill())),
            ),
          ),
        );

        await tester.pump();

        // Tap widget lingkaran
        await tester.tap(find.byType(MekaarFloatingUpdatePill));
        await tester.pumpAndSettle();

        // Memastikan sheet progress terbuka
        expect(find.text('Mengunduh MEKAAR'), findsOneWidget);
        // Memastikan controller beralih dari minimized ke maximized (isMinimized = false)
        expect(fakeController.state.isMinimized, isFalse);
      },
    );

    testWidgets(
      'Tap di luar sheet progress (barrier dismiss) otomatis meminimalkan unduhan (auto-minimize)',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.downloading,
            progress: 0.30,
            isMinimized: false,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: MaterialApp(
              navigatorKey: AppNavigator.navigatorKey,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        MekaarUpdateBottomSheet.showProgressSheet(
                          context: context,
                          info: testInfo,
                        );
                      },
                      child: const Text('Buka Progress'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Buka progress sheet
        await tester.tap(find.text('Buka Progress'));
        await tester.pumpAndSettle();

        expect(find.text('Mengunduh MEKAAR'), findsOneWidget);
        expect(fakeController.state.isMinimized, isFalse);

        // Simulasikan tap di luar sheet (pada barrier di pojok atas)
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Sheet tertutup
        expect(find.text('Mengunduh MEKAAR'), findsNothing);

        // Auto-minimize berhasil terpanggil!
        expect(fakeController.state.isMinimized, isTrue);
      },
    );

    testWidgets(
      'Tap di luar sheet pasang (barrier dismiss) otomatis meminimalkan unduhan (auto-minimize)',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.completed,
            progress: 1.0,
            isMinimized: false,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: MaterialApp(
              navigatorKey: AppNavigator.navigatorKey,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        MekaarUpdateBottomSheet.showInstallSheet(
                          context: context,
                          info: testInfo,
                        );
                      },
                      child: const Text('Buka Pasang'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Buka install sheet
        await tester.tap(find.text('Buka Pasang'));
        await tester.pumpAndSettle();

        expect(find.text('Pembaruan Siap Dipasang!'), findsOneWidget);
        expect(fakeController.state.isMinimized, isFalse);

        // Simulasikan tap di luar sheet (barrier)
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Sheet tertutup
        expect(find.text('Pembaruan Siap Dipasang!'), findsNothing);

        // Auto-minimize berhasil terpanggil!
        expect(fakeController.state.isMinimized, isTrue);
      },
    );

    testWidgets(
      'MekaarUpdateOverlay memposisikan circular pill pada clearance navigasi (bottom: 84 + padding)',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.downloading,
            progress: 0.5,
            isMinimized: true,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(padding: EdgeInsets.only(bottom: 20)),
                child: Scaffold(
                  body: MekaarUpdateOverlay(
                    child: Center(child: Text('Konten Layar')),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Verifikasi Positioned widget yang membungkus MekaarFloatingUpdatePill
        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(MekaarFloatingUpdatePill),
            matching: find.byType(Positioned),
          ),
        );

        // bottom: 84 + 20 (padding) = 104
        expect(positioned.bottom, equals(104.0));
        expect(positioned.right, equals(16.0));
      },
    );

    testWidgets(
      'MekaarUpdateBottomSheet alur in-place morphing: idle -> downloading tanpa menutup sheet & tombol murni teks',
      (tester) async {
        final fakeController = FakeUpdateDownloadController(
          UpdateService(),
          const UpdateDownloadState(
            status: UpdateDownloadStatus.idle,
            info: testInfo,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateDownloadProvider.overrideWith((ref) => fakeController),
            ],
            child: MaterialApp(
              navigatorKey: AppNavigator.navigatorKey,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        MekaarUpdateBottomSheet.show(
                          context: context,
                          info: testInfo,
                        );
                      },
                      child: const Text('Buka Update'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Buka Update Sheet
        await tester.tap(find.text('Buka Update'));
        await tester.pumpAndSettle();

        // 1. Verifikasi Header, Emblem Sentral, dan Pill Versi
        expect(find.text('Pembaruan Tersedia'), findsOneWidget);
        expect(find.text('Versi 2.0.0 • 20 MB'), findsOneWidget);
        expect(find.text('Apa yang baru:'), findsOneWidget);

        // 2. Verifikasi Tombol Idle: Teks murni tanpa ikon/emoji
        expect(find.text('Perbarui Sekarang'), findsOneWidget);
        expect(find.text('Ingatkan Nanti'), findsOneWidget);

        // 3. Ketuk 'Perbarui Sekarang'
        await tester.tap(find.text('Perbarui Sekarang'));
        await tester.pump();

        // Simulasikan state berubah menjadi downloading
        fakeController.updateState(
          const UpdateDownloadState(
            status: UpdateDownloadStatus.downloading,
            progress: 0.35,
            receivedBytes: 7 * 1024 * 1024,
            totalBytes: 20 * 1024 * 1024,
            info: testInfo,
          ),
        );
        await tester.pumpAndSettle();

        // 4. Verifikasi sheet TIDAK tertutup (tetap terbuka) dan bertransisi in-place
        expect(find.text('Mengunduh MEKAAR'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Jeda Unduhan'), findsOneWidget);
        expect(find.text('Minimalkan'), findsOneWidget);

        // Memastikan tidak ada tombol ikon di dalam area aksi
        final actionButtons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
        for (final btn in actionButtons) {
          expect(btn.child is Row, isFalse, reason: 'Tombol tidak boleh menggabungkan ikon dan teks');
        }
      },
    );
  });
}
