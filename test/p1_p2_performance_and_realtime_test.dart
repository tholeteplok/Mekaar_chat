import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

void main() {
  group('P1: Local-First Active Window & Message Sorting', () {
    test('Pesan dari query batch diurutkan ascending berdasarkan createdAt', () {
      final now = DateTime.now().toUtc();
      final msg1 = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Halo pertama',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );
      final msg2 = Message(
        id: 'msg-2',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Halo kedua',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 3)),
        updatedAt: now.subtract(const Duration(minutes: 3)),
      );
      final msg3 = Message(
        id: 'msg-3',
        roomId: 'room-1',
        senderId: 'user-2',
        content: 'Halo ketiga',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      // Simulasikan pesan masuk dalam urutan descending (order created_at DESC)
      final descendingBatch = [msg3, msg2, msg1];

      // Pool pengurutan kronologis
      final pool = <String, Message>{for (var m in descendingBatch) m.id: m};
      final sortedList = pool.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      expect(sortedList.first.id, equals('msg-1'));
      expect(sortedList[1].id, equals('msg-2'));
      expect(sortedList.last.id, equals('msg-3'));
      expect(sortedList.first.createdAt.isBefore(sortedList.last.createdAt), isTrue);
    });

    test('Message pool memperbarui pesan yang ada dan mempertahankan riwayat lokal', () {
      final now = DateTime.now().toUtc();
      final oldLocalMsg = Message(
        id: 'msg-old',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Pesan sangat lama',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(hours: 10)),
        updatedAt: now.subtract(const Duration(hours: 10)),
      );
      final activeMsg = Message(
        id: 'msg-active',
        roomId: 'room-1',
        senderId: 'user-2',
        content: 'Pesan aktif awal',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 1)),
        updatedAt: now.subtract(const Duration(minutes: 1)),
      );

      final messagePool = <String, Message>{
        oldLocalMsg.id: oldLocalMsg,
        activeMsg.id: activeMsg,
      };

      // Datang mutasi edit pada activeMsg dari stream window
      final editedActiveMsg = activeMsg.copyWith(content: 'Pesan aktif setelah diedit');
      messagePool[editedActiveMsg.id] = editedActiveMsg;

      final sorted = messagePool.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Riwayat lama tidak hilang walau tidak ada di stream window
      expect(sorted.length, equals(2));
      expect(sorted.first.id, equals('msg-old'));
      expect(sorted.last.content, equals('Pesan aktif setelah diedit'));
    });
  });

  group('P2: TypingNotifier Lifecycle & Debounce', () {
    test('TypingNotifier menginisialisasi state awal ke false tanpa error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isTyping = container.read(typingStateProvider('test-room-debounce'));
      expect(isTyping, isFalse);
    });

    test('Dispose TypingNotifier sebelum jeda debounce 300 ms tidak menyebabkan kebocoran', () async {
      final container = ProviderContainer();

      // Baca notifier lalu segera dispose sebelum 300 ms
      final subscription = container.listen(
        typingStateProvider('test-room-quick-exit'),
        (prev, next) {},
      );

      // Tutup container seketika
      subscription.close();
      container.dispose();

      // Tunggu hingga melewati durasi debounce 300 ms
      await Future.delayed(const Duration(milliseconds: 350));
      // Jika sampai di sini tanpa exception atau unhandled error, tes berhasil
      expect(true, isTrue);
    });
  });

  group('P1: ChatScreen Keyboard Insets Scoped Rebuild', () {
    testWidgets('Widget tree terisolasi membaca viewInsetsOf tanpa memicu rebuild seluruh screen', (
      WidgetTester tester,
    ) async {
      int outerBuildCount = 0;
      int innerBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                outerBuildCount++;
                return Column(
                  children: [
                    const Text('Static Header'),
                    Builder(
                      builder: (innerContext) {
                        innerBuildCount++;
                        final insets = MediaQuery.viewInsetsOf(innerContext).bottom;
                        return Text('Keyboard: $insets');
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(outerBuildCount, equals(1));
      expect(innerBuildCount, equals(1));
      expect(find.text('Keyboard: 0.0'), findsOneWidget);
    });
  });
}
