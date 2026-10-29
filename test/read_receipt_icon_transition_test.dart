import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/constants/icons.dart';
import 'package:mekaar_chat/core/widgets/bubbles/read_receipt_icon.dart';

Widget _wrapReceipt({
  required ReadReceiptStatus status,
  bool disableAnimations = false,
  Color color = Colors.black,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: ReadReceiptIcon(
            status: status,
            color: color,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ReadReceiptIcon Transition Tests (UX-05)', () {
    testWidgets('Initial mount does not schedule pending transition animation',
        (tester) async {
      await tester.pumpWidget(
        _wrapReceipt(status: ReadReceiptStatus.read),
      );

      expect(find.byIcon(MekaarIcons.receiptRead), findsOneWidget);
      // AnimatedSwitcher berada pada kondisi idle (transientCallbackCount == 0, tidak ada ticker aktif)
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Status transition performs cross-fade and scale animation',
        (tester) async {
      await tester.pumpWidget(
        _wrapReceipt(status: ReadReceiptStatus.pending),
      );

      expect(find.byIcon(MekaarIcons.timerOutlined), findsOneWidget);
      expect(find.byIcon(MekaarIcons.receiptSent), findsNothing);

      // Ubah status ke sent
      await tester.pumpWidget(
        _wrapReceipt(status: ReadReceiptStatus.sent),
      );

      // Pump di tengah-tengah transisi (75ms dari total 150ms MekaarMotion.fast)
      await tester.pump(const Duration(milliseconds: 75));

      // Kedua ikon hadir sementara selama transisi AnimatedSwitcher
      expect(find.byIcon(MekaarIcons.timerOutlined), findsOneWidget);
      expect(find.byIcon(MekaarIcons.receiptSent), findsOneWidget);

      // Selesaikan transisi
      await tester.pumpAndSettle();

      expect(find.byIcon(MekaarIcons.timerOutlined), findsNothing);
      expect(find.byIcon(MekaarIcons.receiptSent), findsOneWidget);
    });

    testWidgets('Status transition finishes immediately when reduceMotion is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapReceipt(
          status: ReadReceiptStatus.pending,
          disableAnimations: true,
        ),
      );

      expect(find.byIcon(MekaarIcons.timerOutlined), findsOneWidget);

      // Ubah status ke delivered dengan reduceMotion aktif
      await tester.pumpWidget(
        _wrapReceipt(
          status: ReadReceiptStatus.delivered,
          disableAnimations: true,
        ),
      );

      // Karena duration: Duration.zero, transisi selesai pada pump pertama
      await tester.pump();

      expect(find.byIcon(MekaarIcons.timerOutlined), findsNothing);
      expect(find.byIcon(MekaarIcons.receiptDelivered), findsOneWidget);
    });

    testWidgets('Bounding box is stably locked to 16x16 across all statuses',
        (tester) async {
      for (final status in ReadReceiptStatus.values) {
        await tester.pumpWidget(
          _wrapReceipt(status: status),
        );

        final receiptFinder = find.byType(ReadReceiptIcon);
        expect(receiptFinder, findsOneWidget);

        final size = tester.getSize(receiptFinder);
        expect(size.width, equals(16.0));
        expect(size.height, equals(16.0));
      }
    });

    testWidgets('Read status renders with MekaarColors.readReceiptGreen',
        (tester) async {
      await tester.pumpWidget(
        _wrapReceipt(status: ReadReceiptStatus.read),
      );

      final icon = tester.widget<Icon>(find.byIcon(MekaarIcons.receiptRead));
      expect(icon.color, equals(MekaarColors.readReceiptGreen));
    });
  });
}
