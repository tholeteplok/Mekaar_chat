import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/utils/chat_key_registry.dart';
import 'package:mekaar_chat/features/settings/providers/chat_theme_provider.dart';

class _TestChatThemeNotifier extends ChatThemeNotifier {
  _TestChatThemeNotifier([ChatThemePreference? pref]) {
    state = AsyncValue.data(
      pref ?? const ChatThemePreference(preset: ChatThemePreset.mekaar),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMsg = Message(
    id: 'test_msg_1',
    roomId: 'room_1',
    senderId: 'other_user',
    content: 'Pesan Riwayat Lama',
    type: MessageType.text,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('ChatBubble Entrance Anti-Flicker Tests', () {
    testWidgets(
      'Pesan riwayat (animateEntrance: false) TIDAK membungkus dengan AnimatedPresetBubbleEntrance',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatThemeProvider.overrideWith((ref) => _TestChatThemeNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChatBubble(
                  message: testMsg,
                  isMe: false,
                  animateEntrance: false, // Riwayat obrolan lama
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifikasi teks muncul tanpa wrapper AnimatedPresetBubbleEntrance
        expect(find.text('Pesan Riwayat Lama'), findsOneWidget);
        expect(find.byType(AnimatedPresetBubbleEntrance), findsNothing);
      },
    );

    testWidgets(
      'Pesan realtime baru (animateEntrance: true) membungkus dengan AnimatedPresetBubbleEntrance',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatThemeProvider.overrideWith((ref) => _TestChatThemeNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChatBubble(
                  message: testMsg,
                  isMe: false,
                  animateEntrance: true, // Pesan baru tiba di room
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AnimatedPresetBubbleEntrance), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('Pesan Riwayat Lama'), findsOneWidget);
      },
    );
  });

  group('ChatKeyRegistry Tests', () {
    test(
      'Mengembalikan instance GlobalKey yang identik untuk messageId yang sama',
      () {
        ChatKeyRegistry.clear();
        final key1 = ChatKeyRegistry.getKey('msg_abc');
        final key2 = ChatKeyRegistry.getKey('msg_abc');
        final keyOther = ChatKeyRegistry.getKey('msg_xyz');

        expect(identical(key1, key2), isTrue);
        expect(key1, equals(key2));
        expect(identical(key1, keyOther), isFalse);
      },
    );

    test('clear() mengosongkan seluruh cache registry', () {
      final key1 = ChatKeyRegistry.getKey('msg_123');
      ChatKeyRegistry.clear();
      final key2 = ChatKeyRegistry.getKey('msg_123');

      // Setelah di-clear, dibuat instance baru
      expect(identical(key1, key2), isFalse);
    });
  });

  group('BubbleMediaHelper Pre-warm and Synchronous Memory Cache Tests', () {
    test(
      'registerLocalMedia mendaftarkan berkas secara instan di memory cache',
      () {
        final tempFile = File('${Directory.systemTemp.path}/test_image.jpg');
        tempFile.writeAsStringSync('fake_bytes');

        try {
          registerLocalMedia('msg_media_1', tempFile);
          final cached = getDecryptedFromMemory('msg_media_1');
          expect(cached, isNotNull);
          expect(cached!.path, equals(tempFile.path));
        } finally {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        }
      },
    );

    test(
      'getDecryptedFromMemory memeriksa disk cache sinkron jika path temp diset',
      () {
        clearDecryptedMemoryCacheForTesting();
        final tempDir = Directory.systemTemp.createTempSync(
          'mekaar_test_media',
        );
        setDecryptedTempDirPathForTesting(tempDir.path);

        final diskFile = File('${tempDir.path}/decrypted_msg_disk_1.jpg');
        diskFile.writeAsStringSync('image_content');

        try {
          final retrieved = getDecryptedFromMemory(
            'msg_disk_1',
            'https://example.com/photo.jpg',
          );
          expect(retrieved, isNotNull);
          expect(retrieved!.existsSync(), isTrue);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });
}
