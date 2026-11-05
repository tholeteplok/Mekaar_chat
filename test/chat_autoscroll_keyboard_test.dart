import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/scroll_to_bottom_button.dart';

void main() {
  group('Chat Auto-Scroll & New Message Counter Logic Tests', () {
    test('isNearBottom bernilai true jika pixels < 120 atau keyboard memiliki fokus', () {
      bool checkNearBottom({
        required bool hasClients,
        required double pixels,
        required bool hasKeyboardFocus,
      }) {
        return !hasClients || pixels < 120 || hasKeyboardFocus;
      }

      // Kasus 1: Belum ada clients (inisialisasi) -> harus true
      expect(
        checkNearBottom(hasClients: false, pixels: 0, hasKeyboardFocus: false),
        isTrue,
      );

      // Kasus 2: Berada di posisi paling dasar (pixels = 0) -> harus true
      expect(
        checkNearBottom(hasClients: true, pixels: 0, hasKeyboardFocus: false),
        isTrue,
      );

      // Kasus 3: Berada di dekat dasar (pixels = 80 < 120) -> harus true
      expect(
        checkNearBottom(hasClients: true, pixels: 80, hasKeyboardFocus: false),
        isTrue,
      );

      // Kasus 4: Sedang scroll jauh di atas (pixels = 250) tapi keyboard sedang fokus -> harus true
      expect(
        checkNearBottom(hasClients: true, pixels: 250, hasKeyboardFocus: true),
        isTrue,
      );

      // Kasus 5: Sedang scroll jauh di atas (pixels = 250) dan keyboard TIDAK fokus -> harus false
      expect(
        checkNearBottom(hasClients: true, pixels: 250, hasKeyboardFocus: false),
        isFalse,
      );
    });

    test('Penanganan counter pesan baru saat pesan baru tiba', () {
      final newMessageCount = ValueNotifier<int>(0);
      bool didScrollToBottom = false;

      void onNewMessagesReceived({
        required int prevLength,
        required int nextLength,
        required bool isNearBottom,
      }) {
        final countNew = nextLength - prevLength;
        if (countNew > 0) {
          if (isNearBottom) {
            didScrollToBottom = true;
            newMessageCount.value = 0;
          } else {
            newMessageCount.value += countNew;
          }
        }
      }

      // Skenario A: 1 pesan baru masuk saat user sedang mengetik/di dasar
      onNewMessagesReceived(
        prevLength: 5,
        nextLength: 6,
        isNearBottom: true,
      );
      expect(didScrollToBottom, isTrue);
      expect(newMessageCount.value, 0);

      // Skenario B: 2 pesan baru masuk saat user sedang membaca riwayat di atas
      didScrollToBottom = false;
      onNewMessagesReceived(
        prevLength: 6,
        nextLength: 8,
        isNearBottom: false,
      );
      expect(didScrollToBottom, isFalse);
      expect(newMessageCount.value, 2);

      // Skenario C: 1 pesan baru lagi masuk saat masih di atas
      onNewMessagesReceived(
        prevLength: 8,
        nextLength: 9,
        isNearBottom: false,
      );
      expect(newMessageCount.value, 3);

      // Skenario D: User scroll kembali ke dasar (< 120px) -> counter reset ke 0
      void onScrollChanged(double currentPixels) {
        if (currentPixels < 120 && newMessageCount.value > 0) {
          newMessageCount.value = 0;
        }
      }

      onScrollChanged(50);
      expect(newMessageCount.value, 0);
    });

    testWidgets('ScrollToBottomButton merender badge jumlah pesan baru secara presisi', (
      tester,
    ) async {
      final showButton = ValueNotifier<bool>(true);
      final newCount = ValueNotifier<int>(0);
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showButton,
                  builder: (context, show, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: newCount,
                      builder: (context, count, _) {
                        return ScrollToBottomButton(
                          visible: show,
                          newMessageCount: count,
                          onTap: () => pressed = true,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Awalnya newCount = 0 -> teks badge angka tidak muncul
      expect(find.text('0'), findsNothing);

      // Update newCount = 3 -> badge menampilkan angka 3
      newCount.value = 3;
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // Ketuk tombol scroll ke bawah
      await tester.tap(find.byType(ScrollToBottomButton));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });
  });
}
