import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/link_risk.dart';
import 'package:mekaar_chat/core/widgets/mekaar_link_text.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Link Risk Assessment Unit Tests', () {
    test('Mendeteksi insecure HTTP', () {
      final res = assessLink('http://example.com/login');
      expect(res.risks, contains(LinkRisk.insecureHttp));
      expect(res.isHighRisk, isFalse);
      expect(res.isBlocked, isFalse);
      expect(res.host, 'example.com');
    });

    test('Mendeteksi Punycode IDN homograph sebagai risiko tinggi', () {
      final res = assessLink('https://xn--pple-43d.com');
      expect(res.risks, contains(LinkRisk.punycode));
      expect(res.isHighRisk, isTrue);
      expect(res.isBlocked, isFalse);
      expect(res.host, 'xn--pple-43d.com');
    });

    test('Mendeteksi host berupa IP address langsung', () {
      final res = assessLink('http://192.168.1.1/admin');
      expect(res.risks, contains(LinkRisk.ipAddressHost));
      expect(res.risks, contains(LinkRisk.insecureHttp));
      expect(res.isBlocked, isFalse);
      expect(res.host, '192.168.1.1');
    });

    test(
      'Mendeteksi UserInfo (kredensial sebelum domain) sebagai risiko tinggi',
      () {
        final res = assessLink('https://admin:secret@bank.com/dashboard');
        expect(res.risks, contains(LinkRisk.userInfo));
        expect(res.isHighRisk, isTrue);
        expect(res.isBlocked, isFalse);
        expect(res.host, 'bank.com');
      },
    );

    test('Mendeteksi domain pemendek URL populer', () {
      final res = assessLink('https://bit.ly/3xYz123');
      expect(res.risks, contains(LinkRisk.shortener));
      expect(res.isHighRisk, isFalse);
      expect(res.isBlocked, isFalse);
      expect(res.host, 'bit.ly');
    });

    test('Mendeteksi port non-standar', () {
      final res = assessLink('https://example.com:8443/api');
      expect(res.risks, contains(LinkRisk.nonStandardPort));
      expect(res.isBlocked, isFalse);
      expect(res.host, 'example.com');
    });

    test('Mendeteksi URL sangat panjang (> 300 karakter)', () {
      final longQuery = 'a' * 310;
      final res = assessLink('https://example.com/search?q=$longQuery');
      expect(res.risks, contains(LinkRisk.veryLong));
      expect(res.isBlocked, isFalse);
    });

    test('Memblokir skema berbahaya (javascript:, file:, intent:)', () {
      final jsRes = assessLink('javascript:alert(1)');
      expect(jsRes.isBlocked, isTrue);
      expect(jsRes.risks, contains(LinkRisk.blockedScheme));

      final fileRes = assessLink('file:///etc/passwd');
      expect(fileRes.isBlocked, isTrue);
      expect(fileRes.risks, contains(LinkRisk.blockedScheme));

      final intentRes = assessLink('intent://scan/#Intent;scheme=zxing;end');
      expect(intentRes.isBlocked, isTrue);
      expect(intentRes.risks, contains(LinkRisk.blockedScheme));
    });

    test('Mengevaluasi tautan bersih/aman tanpa risiko', () {
      final res = assessLink('https://mekaar.id/panduan');
      expect(res.risks, isEmpty);
      expect(res.isHighRisk, isFalse);
      expect(res.isBlocked, isFalse);
      expect(res.host, 'mekaar.id');
      expect(res.normalizedUrl, 'https://mekaar.id/panduan');
    });
  });

  group('Link Confirmation Dialog Widget Tests', () {
    testWidgets(
      'Menampilkan dialog tautan aman dengan tombol "Buka Tautan" dan tombol Salin',
      (tester) async {
        String? copiedString;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              copiedString = (methodCall.arguments as Map)['text'] as String?;
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showMekaarLinkConfirmationDialog(
                        context,
                        'https://mekaar.id/privacy',
                      );
                    },
                    child: const Text('Buka'),
                  );
                },
              ),
            ),
          ),
        );

        // Buka dialog
        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        // Verifikasi dialog
        expect(find.text('Buka Tautan Eksternal'), findsOneWidget);
        expect(find.text('mekaar.id'), findsOneWidget);
        expect(find.text('https://mekaar.id/privacy'), findsOneWidget);
        expect(find.text('Buka Tautan'), findsOneWidget);

        // Verifikasi tombol salin
        final copyBtn = find.byIcon(SolarIconsOutline.copy);
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        expect(copiedString, equals('https://mekaar.id/privacy'));
        expect(find.text('Tautan disalin'), findsOneWidget);

        // Tutup dialog
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.text('Buka Tautan Eksternal'), findsNothing);
      },
    );

    testWidgets(
      'Menampilkan peringatan risiko tinggi dengan tombol "Tetap Buka"',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showMekaarLinkConfirmationDialog(
                        context,
                        'https://xn--pple-43d.com',
                      );
                    },
                    child: const Text('Buka Riskan'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Riskan'));
        await tester.pumpAndSettle();

        expect(find.text('Peringatan Keamanan Tautan'), findsOneWidget);
        expect(find.text('Tetap Buka'), findsOneWidget);
        expect(
          find.textContaining('karakter khusus (punycode)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Menonaktifkan tombol buka untuk tautan dengan skema berbahaya yang diblokir',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showMekaarLinkConfirmationDialog(
                        context,
                        'javascript:alert(document.cookie)',
                      );
                    },
                    child: const Text('Buka Berbahaya'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Berbahaya'));
        await tester.pumpAndSettle();

        expect(find.text('Tautan Berbahaya / Diblokir'), findsOneWidget);
        final blockedButtonFinder = find.widgetWithText(
          FilledButton,
          'Tautan Diblokir',
        );
        expect(blockedButtonFinder, findsOneWidget);

        final filledButton = tester.widget<FilledButton>(blockedButtonFinder);
        expect(filledButton.onPressed, isNull); // Tombol dinonaktifkan
      },
    );
  });
}
