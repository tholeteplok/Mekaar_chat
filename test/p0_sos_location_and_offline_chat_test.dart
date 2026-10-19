import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/error_resolver.dart';
import 'package:mekaar_chat/core/widgets/mekaar_banner.dart';
import 'package:mekaar_chat/core/widgets/mekaar_dialog.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('P0: ErrorResolver.isNetworkError', () {
    test('mendeteksi SocketException dan TimeoutException sebagai error jaringan', () {
      expect(ErrorResolver.isNetworkError(const SocketException('No route to host')), isTrue);
      expect(ErrorResolver.isNetworkError(TimeoutException('Request timed out')), isTrue);
    });

    test('mendeteksi error string jaringan, timeout, dan realtime subscription', () {
      expect(ErrorResolver.isNetworkError('ClientException: XMLHttpRequest error'), isTrue);
      expect(ErrorResolver.isNetworkError('RealtimeSubscribeException(timedOut)'), isTrue);
      expect(ErrorResolver.isNetworkError('failed host lookup: sub.supabase.co'), isTrue);
      expect(ErrorResolver.isNetworkError('connection refused by peer'), isTrue);
    });

    test('mengembalikan false untuk error non-jaringan atau null', () {
      expect(ErrorResolver.isNetworkError(null), isFalse);
      expect(ErrorResolver.isNetworkError(const AuthException('Invalid email')), isFalse);
      expect(
        ErrorResolver.isNetworkError(
          const PostgrestException(message: 'Row not found', code: 'PGRST116'),
        ),
        isFalse,
      );
      expect(ErrorResolver.isNetworkError(const FormatException('Bad JSON')), isFalse);
    });
  });

  group('P0: SOS Location Safety Dialog', () {
    testWidgets('MekaarDialog.showLocationPermissionDeniedWarning menampilkan 1-tap dialog keselamatan', (
      WidgetTester tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await MekaarDialog.showLocationPermissionDeniedWarning(
                    context: context,
                  );
                },
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      // Buka dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Verifikasi dialog keselamatan in-app 1-tap
      expect(find.text('Izin Lokasi Tidak Aktif'), findsOneWidget);
      expect(
        find.textContaining('tidak dapat dilacak secara langsung oleh wali darurat'),
        findsOneWidget,
      );
      expect(find.text('Mengerti & Lanjutkan SOS'), findsOneWidget);

      // Tap 1-tap konfirmasi
      await tester.tap(find.text('Mengerti & Lanjutkan SOS'));
      await tester.pumpAndSettle();

      // Dialog harus tertutup dan mengembalikan true
      expect(find.text('Izin Lokasi Tidak Aktif'), findsNothing);
      expect(result, isTrue);
    });
  });

  group('P0: SOSState locationPermissionDenied', () {
    test('default nilai locationPermissionDenied adalah false', () {
      final state = SOSState();
      expect(state.locationPermissionDenied, isFalse);
    });

    test('copyWith memperbarui locationPermissionDenied dengan benar', () {
      final state = SOSState();
      final updated = state.copyWith(locationPermissionDenied: true);
      expect(updated.locationPermissionDenied, isTrue);

      final reverted = updated.copyWith(locationPermissionDenied: false);
      expect(reverted.locationPermissionDenied, isFalse);
    });
  });

  group('P0: MekaarBanner.offlineMode', () {
    testWidgets('merender banner mode offline statis sesuai standar desain MEKAAR', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarBanner.offlineMode(),
          ),
        ),
      );

      expect(find.text('Mode Offline'), findsOneWidget);
      expect(find.text('Menampilkan riwayat obrolan tersimpan'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.cloudCross), findsOneWidget);
    });
  });
}
