import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_snackbar.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

void main() {
  group('MekaarSnackbar.undo Unit Tests (UX-11)', () {
    testWidgets('menampilkan teks pesan dan tombol aksi "Urungkan"', (
      tester,
    ) async {
      bool undoTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MekaarSnackbar.undo(
                      context,
                      'Pesan disembunyikan untuk Anda',
                      onUndo: () {
                        undoTriggered = true;
                      },
                    );
                  },
                  child: const Text('Show Undo'),
                );
              },
            ),
          ),
        ),
      );

      // Ketuk tombol untuk memunculkan snackbar
      await tester.tap(find.text('Show Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Pesan disembunyikan untuk Anda'), findsOneWidget);
      expect(find.text('Urungkan'), findsOneWidget);
      expect(undoTriggered, isFalse);

      // Ketuk tombol aksi 'Urungkan'
      await tester.tap(find.text('Urungkan'));
      await tester.pump();

      expect(undoTriggered, isTrue);
    });

    testWidgets('menghormati custom actionLabel dan durasi default 5 detik', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MekaarSnackbar.undo(
                      context,
                      'Operasi berhasil',
                      actionLabel: 'Batalkan',
                      onUndo: () {},
                    );
                  },
                  child: const Text('Show Custom'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Custom'));
      await tester.pump();

      expect(find.text('Batalkan'), findsOneWidget);
    });
  });

  group('Deferred Commit (S2) Provider Tests (UX-11)', () {
    test('pendingHiddenMessagesProvider menyaring pesan secara optimis', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const roomId = 'room_abc';
      final now = DateTime.now();

      final msg1 = Message(
        id: 'msg_1',
        roomId: roomId,
        senderId: 'user_other',
        content: 'Halo',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );
      final msg2 = Message(
        id: 'msg_2',
        roomId: roomId,
        senderId: 'user_other',
        content: 'Dua',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      final rawMessages = [msg1, msg2];

      // Awalnya tidak ada pending hidden
      var pending = container.read(pendingHiddenMessagesProvider(roomId));
      expect(pending, isEmpty);

      var visible = rawMessages.where((m) => !pending.contains(m.id)).toList();
      expect(visible.length, 2);

      // Simulasikan penghapusan optimis msg_1
      container.read(pendingHiddenMessagesProvider(roomId).notifier).state = {
        'msg_1',
      };
      pending = container.read(pendingHiddenMessagesProvider(roomId));
      expect(pending, contains('msg_1'));

      visible = rawMessages.where((m) => !pending.contains(m.id)).toList();
      expect(visible.length, 1);
      expect(visible.first.id, 'msg_2');

      // Simulasikan Urungkan (kembali)
      container.read(pendingHiddenMessagesProvider(roomId).notifier).state = {};
      pending = container.read(pendingHiddenMessagesProvider(roomId));
      expect(pending, isEmpty);

      visible = rawMessages.where((m) => !pending.contains(m.id)).toList();
      expect(visible.length, 2);
    });

    testWidgets('Timer 5 detik mengeksekusi commit jika tidak di-undo', (
      tester,
    ) async {
      bool committed = false;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const roomId = 'room_123';
      const msgId = 'msg_target';

      // Sembunyikan optimis
      container.read(pendingHiddenMessagesProvider(roomId).notifier).state = {
        msgId,
      };

      // Jalankan timer 5 detik
      final timer = Timer(const Duration(seconds: 5), () {
        committed = true;
        container.read(pendingHiddenMessagesProvider(roomId).notifier).state =
            {};
      });

      expect(committed, isFalse);
      expect(
        container.read(pendingHiddenMessagesProvider(roomId)),
        contains(msgId),
      );

      // Pompa waktu 4 detik (belum commit)
      await tester.pump(const Duration(seconds: 4));
      expect(committed, isFalse);

      // Pompa lagi 1 detik (total 5 detik) -> commit
      await tester.pump(const Duration(seconds: 1));
      expect(committed, isTrue);
      expect(container.read(pendingHiddenMessagesProvider(roomId)), isEmpty);

      timer.cancel();
    });

    testWidgets(
      'Urungkan membatalkan Timer sebelum 5 detik sehingga tidak ter-commit',
      (tester) async {
        bool committed = false;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const roomId = 'room_123';
        const msgId = 'msg_target';

        // Sembunyikan optimis
        container.read(pendingHiddenMessagesProvider(roomId).notifier).state = {
          msgId,
        };

        final timer = Timer(const Duration(seconds: 5), () {
          committed = true;
        });

        // Pengguna menekan 'Urungkan' setelah 2 detik
        await tester.pump(const Duration(seconds: 2));
        timer.cancel(); // Batalkan timer
        container.read(pendingHiddenMessagesProvider(roomId).notifier).state =
            {}; // Pulihkan UI

        // Lanjutkan waktu 10 detik ke depan
        await tester.pump(const Duration(seconds: 10));

        expect(committed, isFalse);
        expect(container.read(pendingHiddenMessagesProvider(roomId)), isEmpty);
      },
    );
  });
}
