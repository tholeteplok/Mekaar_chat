import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(SupabaseService());

  @override
  Future<List<Map<String, dynamic>>> getRooms() async {
    return [
      {
        'id': 'room_1',
        'name': 'Alice',
        'lastMessage': 'Halo lama',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'unreadCount': 0,
      },
      {
        'id': 'room_2',
        'name': 'Bob',
        'lastMessage': 'Pesan Bob',
        'timestamp': DateTime(2026, 1, 2).toIso8601String(),
        'unreadCount': 2,
      },
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Keyboard Stability & ChatComposer Tests', () {
    testWidgets('ChatComposer menggunakan external FocusNode dan TextField tetap aktif',
        (tester) async {
      final controller = TextEditingController();
      final externalFocusNode = FocusNode();
      bool sendTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ChatComposer(
                controller: controller,
                focusNode: externalFocusNode,
                replyMessage: null,
                onSend: () => sendTriggered = true,
                onCancelReply: () {},
                enabled: true,
                canSend: false, // Menyimulasikan E2EE belum ready
              ),
            ),
          ),
        ),
      );

      // Pastikan TextField ada dan berstatus enabled
      final textFieldFinder = find.byKey(const ValueKey('chat_composer_text_field'));
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.enabled, isTrue);
      expect(textField.focusNode, equals(externalFocusNode));

      // Isi teks
      controller.text = 'Halo pesan rahasia';
      await tester.pump();

      // Coba klik kirim saat canSend = false
      final sendFinder = find.bySemanticsLabel('Kirim pesan');
      expect(sendFinder, findsOneWidget);
      await tester.tap(sendFinder);
      await tester.pump();

      // onSend TIDAK boleh dipanggil karena canSend bernilai false
      expect(sendTriggered, isFalse);

      externalFocusNode.dispose();
      controller.dispose();
    });

    testWidgets('ChatComposer memicu onSend saat canSend bernilai true',
        (tester) async {
      final controller = TextEditingController(text: 'Pesan terkirim');
      bool sendTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ChatComposer(
                controller: controller,
                replyMessage: null,
                onSend: () => sendTriggered = true,
                onCancelReply: () {},
                enabled: true,
                canSend: true, // E2EE ready
              ),
            ),
          ),
        ),
      );

      final sendFinder = find.bySemanticsLabel('Kirim pesan');
      await tester.tap(sendFinder);
      await tester.pump();

      expect(sendTriggered, isTrue);
      controller.dispose();
    });
  });

  group('Optimistic Local-First ChatRoomsNotifier Tests', () {
    test('updateLastMessageLocally memindahkan room ke index 0 dan mengupdate data',
        () async {
      final repo = _FakeChatRepository();
      final notifier = ChatRoomsNotifier(repo);

      // Tunggu refreshRooms selesai inisialisasi
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.value, isNotNull);
      expect(notifier.state.value!.first['id'], equals('room_1'));

      final now = DateTime(2026, 10, 22, 10, 0, 0);

      // Update room_2 dari pihak lawan saat user di luar ruangan
      notifier.updateLastMessageLocally(
        roomId: 'room_2',
        previewText: 'Halo pesan baru dari Bob!',
        timestamp: now,
        isFromOtherUser: true,
        isCurrentlyInRoom: false,
      );

      final updatedList = notifier.state.value!;
      expect(updatedList.first['id'], equals('room_2')); // Naik ke index 0
      expect(updatedList.first['lastMessage'], equals('Halo pesan baru dari Bob!'));
      expect(updatedList.first['unreadCount'], equals(3)); // 2 + 1 = 3
      expect(updatedList.first['timestamp'], equals(now));
    });

    test('updateLastMessageLocally tidak menambah unreadCount jika user sedang di dalam room',
        () async {
      final repo = _FakeChatRepository();
      final notifier = ChatRoomsNotifier(repo);

      await Future.delayed(const Duration(milliseconds: 50));

      final now = DateTime(2026, 10, 22, 10, 5, 0);

      // Update room_2 saat user SEDANG di dalam room_2
      notifier.updateLastMessageLocally(
        roomId: 'room_2',
        previewText: 'Pesan dibaca langsung',
        timestamp: now,
        isFromOtherUser: true,
        isCurrentlyInRoom: true,
      );

      final updatedList = notifier.state.value!;
      expect(updatedList.first['id'], equals('room_2'));
      expect(updatedList.first['unreadCount'], equals(2)); // Tetap 2, tidak bertambah
    });

    test('updateLastMessageLocally tidak menambah unreadCount untuk pesan terkirim sendiri',
        () async {
      final repo = _FakeChatRepository();
      final notifier = ChatRoomsNotifier(repo);

      await Future.delayed(const Duration(milliseconds: 50));

      final now = DateTime(2026, 10, 22, 10, 10, 0);

      // User mengirim pesan sendiri di room_1
      notifier.updateLastMessageLocally(
        roomId: 'room_1',
        previewText: 'Pesan keluar saya',
        timestamp: now,
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
      );

      final updatedList = notifier.state.value!;
      expect(updatedList.first['id'], equals('room_1'));
      expect(updatedList.first['lastMessage'], equals('Pesan keluar saya'));
      expect(updatedList.first['unreadCount'], equals(0)); // Tetap 0
    });
  });

  group('MessageNotificationListener.formatPreviewText Tests', () {
    test('format cuplikan pesan teks dan media konsisten', () {
      expect(
        MessageNotificationListener.formatPreviewText(
          msgType: 'text',
          content: 'Halo teman',
          isEncrypted: false,
          isFromOtherUser: true,
        ),
        equals('Halo teman'),
      );

      expect(
        MessageNotificationListener.formatPreviewText(
          msgType: 'image',
          content: '',
          isEncrypted: false,
          isFromOtherUser: true,
        ),
        equals('📷 Foto baru'),
      );

      expect(
        MessageNotificationListener.formatPreviewText(
          msgType: 'image',
          content: '',
          isEncrypted: false,
          isFromOtherUser: false,
        ),
        equals('📷 Foto'),
      );

      expect(
        MessageNotificationListener.formatPreviewText(
          msgType: 'text',
          content: 'cipher_blob',
          isEncrypted: true,
          isFromOtherUser: true,
        ),
        equals('Pesan baru'),
      );

      expect(
        MessageNotificationListener.formatPreviewText(
          msgType: 'text',
          content: 'cipher_blob',
          isEncrypted: true,
          isFromOtherUser: false,
        ),
        equals('••••••••'),
      );
    });
  });
}
