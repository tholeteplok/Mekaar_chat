import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/dialogs/chat_deletion_dialogs.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_e2ee_restore_sheet.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_forward_sheet.dart';

void main() {
  group('ChatDeletionDialogs Widget Tests', () {
    testWidgets('confirmDeleteSingleMessage menampilkan dialog Hapus untuk Saya', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final now = DateTime.now();
      final msg = Message(
        id: 'msg_test_1',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Test content',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      ChatDeletionDialogs.confirmDeleteSingleMessage(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        message: msg,
      );

      await tester.pumpAndSettle();

      expect(find.text('Hapus untuk Saya?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Hapus untuk Saya'), findsOneWidget);
    });

    testWidgets('confirmUnsingleMessage menampilkan dialog Tarik Pesan', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final now = DateTime.now();
      final msg = Message(
        id: 'msg_test_2',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Tarik pesan ini',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      ChatDeletionDialogs.confirmUnsingleMessage(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        message: msg,
        isGuardian: false,
      );

      await tester.pumpAndSettle();

      expect(find.text('Tarik Pesan?'), findsOneWidget);
      expect(find.text('Tarik untuk Semua'), findsOneWidget);
    });

    testWidgets('confirmClearHistory menampilkan dialog Bersihkan Riwayat', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      ChatDeletionDialogs.confirmClearHistory(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        isGuardian: false,
        onCleared: () {},
      );

      await tester.pumpAndSettle();

      expect(find.text('Bersihkan Riwayat di Perangkat Ini?'), findsOneWidget);
      expect(find.text('Bersihkan (Hanya Saya)'), findsOneWidget);
    });

    testWidgets('confirmDeleteChat menampilkan dialog Hapus Percakapan', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      ChatDeletionDialogs.confirmDeleteChat(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        onDeleted: () {},
      );

      await tester.pumpAndSettle();

      expect(find.text('Hapus Percakapan dari Daftar Anda?'), findsOneWidget);
      expect(find.text('Hapus (Hanya Saya)'), findsOneWidget);
    });
  });

  group('ChatForwardSheet & ChatE2eeRestoreSheet Tests', () {
    testWidgets('ChatForwardSheet menampilkan bottom sheet Teruskan ke', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final now = DateTime.now();
      final msg = Message(
        id: 'msg_fwd_1',
        roomId: 'room_current',
        senderId: 'user_1',
        content: 'Forward me',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      // Trigger show
      ChatForwardSheet.show(
        capturedContext,
        ref: capturedRef,
        currentRoomId: 'room_current',
        messages: [msg],
      );

      await tester.pumpAndSettle();

      expect(find.text('Teruskan ke'), findsOneWidget);
      expect(find.text('Tidak ada chat lain untuk meneruskan pesan.'), findsOneWidget);
    });

    testWidgets('ChatE2eeRestoreSheet menampilkan dialog Pulihkan Kunci E2EE', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      ChatE2eeRestoreSheet.show(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        isGroup: false,
      );

      await tester.pumpAndSettle();

      expect(find.text('Pulihkan Kunci E2EE'), findsOneWidget);
      expect(find.text('Reset Kunci'), findsOneWidget);
      expect(find.text('Buka Kunci'), findsOneWidget);
    });
  });
}
