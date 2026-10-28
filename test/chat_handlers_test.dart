import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/handlers/chat_file_action_handler.dart';
import 'package:mekaar_chat/features/chat/handlers/chat_media_handler.dart';

void main() {
  group('ChatFileActionHandler Unit & Widget Tests', () {
    testWidgets('saveToVault tanpa mediaUrl menampilkan snackbar error', (
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
        id: 'msg_no_media',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Hanya teks biasa',
        type: MessageType.text,
        mediaUrl: null,
        createdAt: now,
        updatedAt: now,
      );

      await ChatFileActionHandler.saveToVault(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        message: msg,
        isGroup: false,
        participantNames: {},
        effectiveChatName: 'Sahabat Mekaar',
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada berkas yang dapat disimpan.'),
        findsOneWidget,
      );
    });

    testWidgets('saveSelectedToVault dengan daftar kosong kembali langsung tanpa error', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;
      bool completed = false;

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

      await ChatFileActionHandler.saveSelectedToVault(
        capturedContext,
        ref: capturedRef,
        roomId: 'room_1',
        savableMessages: [],
        isGroup: false,
        participantNames: {},
        effectiveChatName: 'Sahabat Mekaar',
        onCompleted: () => completed = true,
      );

      await tester.pumpAndSettle();
      expect(completed, isFalse);
    });

    testWidgets('downloadSelectedFiles memicu onCompleted saat dipanggil', (
      tester,
    ) async {
      late BuildContext capturedContext;
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await ChatFileActionHandler.downloadSelectedFiles(
        capturedContext,
        downloadableMessages: [],
        onCompleted: () => completed = true,
      );

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });
  });

  group('ChatMediaHandler Tests', () {
    testWidgets('handleInitialSharedFiles mengabaikan daftar berkas kosong', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;
      bool sendMediaCalled = false;

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

      await ChatMediaHandler.handleInitialSharedFiles(
        capturedContext,
        ref: capturedRef,
        filePaths: [],
        onSendMedia: (file, type, {caption, isViewOnce}) async {
          sendMediaCalled = true;
        },
      );

      await tester.pump();
      expect(sendMediaCalled, isFalse);
    });
  });
}
