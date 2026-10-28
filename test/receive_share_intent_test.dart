import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:mekaar_chat/data/services/share_intent_service.dart';
import 'package:mekaar_chat/features/chat/widgets/mekaar_share_target_dialog.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Receive Share Intent Tests', () {
    setUp(() {
      ReceiveSharingIntent.setMockValues(
        initialMedia: [],
        mediaStream: const Stream.empty(),
      );
    });

    test('SharedPayload logic isEmpty & isNotEmpty', () {
      const emptyPayload = SharedPayload();
      expect(emptyPayload.isEmpty, isTrue);
      expect(emptyPayload.isNotEmpty, isFalse);
      expect(emptyPayload.hasText, isFalse);
      expect(emptyPayload.hasFiles, isFalse);

      const textPayload = SharedPayload(text: 'Pesan rahasia');
      expect(textPayload.isEmpty, isFalse);
      expect(textPayload.isNotEmpty, isTrue);
      expect(textPayload.hasText, isTrue);
      expect(textPayload.hasFiles, isFalse);

      const filePayload = SharedPayload(filePaths: ['/storage/image.jpg']);
      expect(filePayload.isEmpty, isFalse);
      expect(filePayload.isNotEmpty, isTrue);
      expect(filePayload.hasText, isFalse);
      expect(filePayload.hasFiles, isTrue);
    });

    test('ShareIntentNotifier setPayload & clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sharedPayloadProvider.notifier);
      expect(container.read(sharedPayloadProvider), isNull);

      notifier.setPayload(const SharedPayload(text: 'Halo Dunia'));
      expect(container.read(sharedPayloadProvider)?.text, equals('Halo Dunia'));

      notifier.clear();
      expect(container.read(sharedPayloadProvider), isNull);
    });

    test('ShareIntentNotifier memproses incoming stream intent', () async {
      final streamController =
          StreamController<List<SharedMediaFile>>.broadcast();
      ReceiveSharingIntent.setMockValues(
        initialMedia: [],
        mediaStream: streamController.stream,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      // Pastikan listener terdaftar
      container.read(sharedPayloadProvider);

      // Simulasikan share teks masuk
      streamController.add([
        SharedMediaFile(
          path: 'https://mekaar.id/dokumen.pdf',
          type: SharedMediaType.url,
        ),
      ]);

      await pumpEventQueue();

      final payload = container.read(sharedPayloadProvider);
      expect(payload, isNotNull);
      expect(payload?.text, equals('https://mekaar.id/dokumen.pdf'));
    });

    testWidgets(
        'MekaarShareTargetDialog merender pratinjau teks dan daftar obrolan',
        (tester) async {
      final sampleRooms = [
        {
          'id': 'room-1',
          'name': 'Budi Santoso',
          'avatar': 'B',
          'avatarUrl': null,
          'isGuardian': false,
          'isGroup': false,
          'otherUserId': 'user-1',
        },
        {
          'id': 'room-2',
          'name': 'Siti Rahma (Guardian)',
          'avatar': 'S',
          'avatarUrl': null,
          'isGuardian': true,
          'isGroup': false,
          'otherUserId': 'user-2',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRoomsProvider.overrideWith(
                (ref) => _FakeChatRoomsNotifier(sampleRooms)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MekaarShareTargetDialog(
                payload: SharedPayload(text: 'Tautan penting untuk kamu'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cek kartu pratinjau
      expect(find.text('Pesan Teks'), findsOneWidget);
      expect(find.text('Tautan penting untuk kamu'), findsOneWidget);

      // Cek item room
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Siti Rahma (Guardian)'), findsOneWidget);
    });
  });
}

class _FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  _FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
