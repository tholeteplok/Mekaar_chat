import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/chat/utils/chat_jump.dart';
import 'package:mekaar_chat/features/chat/widgets/message_flash.dart';

void main() {
  group('Chat Jump Utility (jumpToKeyedItem)', () {
    testWidgets('melompat ke item terdekat yang sudah ada di viewport', (
      tester,
    ) async {
      final controller = ScrollController();
      final targetKey = const GlobalObjectKey('item-5');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (context, index) {
                return Container(
                  key: index == 5 ? targetKey : null,
                  height: 60,
                  alignment: Alignment.center,
                  child: Text('Item $index'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ListView));
      final future = jumpToKeyedItem(
        context: context,
        controller: controller,
        itemKey: targetKey,
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Item 80').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      final result = await future;

      expect(result, isTrue);
      expect(find.text('Item 5'), findsOneWidget);
    });

    testWidgets(
      'melompat secara inkremental ke item yang jauh di luar viewport',
      (tester) async {
        final controller = ScrollController();
        const targetIndex = 80;
        final targetKey = const GlobalObjectKey('item-$targetIndex');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: 200,
                itemBuilder: (context, index) {
                  final height = 50.0 + (index % 5) * 15.0;
                  return Container(
                    key: index == targetIndex ? targetKey : null,
                    height: height,
                    alignment: Alignment.center,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pastikan awalnya item 80 belum dirender karena jauh di luar viewport
        expect(find.text('Item 80'), findsNothing);

        final context = tester.element(find.byType(ListView));
        final future = jumpToKeyedItem(
          context: context,
          controller: controller,
          itemKey: targetKey,
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.text('Item 80').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        final result = await future;

        expect(result, isTrue);
        expect(find.text('Item 80'), findsOneWidget);
      },
    );

    testWidgets(
      'mengembalikan false ketika key item tidak ditemukan dalam list',
      (tester) async {
        final controller = ScrollController();
        final nonExistentKey = const GlobalObjectKey('item-9999');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (context, index) {
                  return SizedBox(height: 50, child: Text('Item $index'));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ListView));
        final future = jumpToKeyedItem(
          context: context,
          controller: controller,
          itemKey: nonExistentKey,
          maxSteps: 5,
        );
        await tester.pumpAndSettle();
        final result = await future;

        expect(result, isFalse);
      },
    );

    testWidgets(
      'melompat pada ListView reverse dengan targetIndex dan totalItems',
      (tester) async {
        final controller = ScrollController();
        const targetIndex = 45;
        final targetKey = GlobalKey(debugLabel: 'msg-45');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                reverse: true,
                itemCount: 100,
                itemBuilder: (context, index) {
                  return Container(
                    key: index == targetIndex ? targetKey : null,
                    height: 70,
                    alignment: Alignment.center,
                    child: Text('Message $index'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Index 45 awalnya di luar viewport
        expect(find.text('Message 45'), findsNothing);

        final context = tester.element(find.byType(ListView));
        final future = jumpToKeyedItem(
          context: context,
          controller: controller,
          itemKey: targetKey,
          targetIndex: targetIndex,
          totalItems: 100,
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.text('Message 45').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        final result = await future;

        expect(result, isTrue);
        expect(find.text('Message 45'), findsOneWidget);
      },
    );
  });

  group('MessageFlash Widget', () {
    testWidgets('menyorot saat flashIdListenable mencocoki messageId', (
      tester,
    ) async {
      final flashId = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageFlash(
              messageId: 'msg-123',
              flashIdListenable: flashId,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 200,
                height: 60,
                child: Text('Pesan 123'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Belum ada sorotan (ClipRRect belum dirender)
      expect(find.byType(ClipRRect), findsNothing);

      // Trigger flash
      flashId.value = 'msg-123';
      await tester.pump(); // frame pertama controller.forward(from: 0.0)
      await tester.pump(const Duration(milliseconds: 100));

      // Sorotan aktif terlihat
      expect(find.byType(ClipRRect), findsOneWidget);

      // Tunggu hingga animasi selesai memudar
      await tester.pumpAndSettle();
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('tidak menyorot jika flashIdListenable berisi id pesan lain', (
      tester,
    ) async {
      final flashId = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageFlash(
              messageId: 'msg-123',
              flashIdListenable: flashId,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 200,
                height: 60,
                child: Text('Pesan 123'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      flashId.value = 'msg-different';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tidak boleh ada sorotan yang dirender
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets(
      'reduce motion menampilkan sorot statis dan mati dengan timer',
      (tester) async {
        final flashId = ValueNotifier<String?>(null);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: MessageFlash(
                  messageId: 'msg-123',
                  flashIdListenable: flashId,
                  borderRadius: BorderRadius.circular(16),
                  child: const SizedBox(
                    width: 200,
                    height: 60,
                    child: Text('Pesan 123'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Belum ada sorotan
        expect(find.byType(ClipRRect), findsNothing);

        flashId.value = 'msg-123';
        await tester.pump();

        // Sorotan statis aktif
        expect(find.byType(ClipRRect), findsOneWidget);

        // Maju 650ms untuk melewati timer reduce motion 600ms
        await tester.pump(const Duration(milliseconds: 650));
        expect(find.byType(ClipRRect), findsNothing);
      },
    );
  });
}
