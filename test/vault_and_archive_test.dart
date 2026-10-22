import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_pin_verification_sheet.dart';
import 'package:mekaar_chat/data/models/vault_item.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/archived_chats_screen.dart';
import 'package:mekaar_chat/features/chat/screens/vault_screen.dart';

class MockChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  MockChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<String> getOrCreateRoom(
    String otherUserId,
    String type, {
    bool screenshotEnabled = true,
  }) async =>
      'dummy-room';

  @override
  void updateLastMessageLocally({
    required String roomId,
    required String previewText,
    required DateTime timestamp,
    required bool isFromOtherUser,
    required bool isCurrentlyInRoom,
  }) {}
}

class MockVaultNotifier
    extends StateNotifier<AsyncValue<List<VaultItem>>>
    implements VaultNotifier {
  MockVaultNotifier(List<VaultItem> items) : super(AsyncValue.data(items));

  @override
  Future<void> loadItems({String? query}) async {}

  @override
  Future<bool> deleteItem(String id) async => true;

  @override
  Future<void> refresh() async {}
}

void main() {
  group('VaultItem Model & Categorization Tests', () {
    test('VaultFileType resolves correct type from file name and mime type', () {
      expect(
        VaultFileType.fromFileNameOrMime('foto_keluarga.jpg'),
        VaultFileType.image,
      );
      expect(
        VaultFileType.fromFileNameOrMime('video_liburan.mp4'),
        VaultFileType.video,
      );
      expect(
        VaultFileType.fromFileNameOrMime('rekaman_suara.m4a'),
        VaultFileType.audio,
      );
      expect(
        VaultFileType.fromFileNameOrMime('laporan.pdf'),
        VaultFileType.document,
      );
      expect(
        VaultFileType.fromFileNameOrMime('berkas.zip'),
        VaultFileType.other,
      );
      expect(
        VaultFileType.fromFileNameOrMime('unknown', mimeType: 'image/png'),
        VaultFileType.image,
      );
      expect(
        VaultFileType.fromFileNameOrMime('unknown', mimeType: 'audio/aac'),
        VaultFileType.audio,
      );
    });

    test('VaultItem formattedFileSize produces human readable format', () {
      final itemBytes = VaultItem(
        id: 'v1',
        fileName: 'test.bin',
        fileType: VaultFileType.other,
        localPath: '/tmp/test.bin',
        fileSizeBytes: 500,
        savedAt: DateTime(2026, 10, 19),
      );
      expect(itemBytes.formattedFileSize, '500 B');

      final itemKB = itemBytes.copyWith(fileSizeBytes: 1024 * 15);
      expect(itemKB.formattedFileSize, '15.0 KB');

      final itemMB = itemBytes.copyWith(fileSizeBytes: 1024 * 1024 * 3 + 500000);
      expect(itemMB.formattedFileSize.contains('MB'), isTrue);
    });

    test('VaultItem serialization & deserialization to/from Map', () {
      final now = DateTime(2026, 10, 19, 12, 0);
      final original = VaultItem(
        id: 'vault-uuid-001',
        originalMessageId: 'msg-999',
        fileName: 'bukti_pembayaran.jpg',
        fileType: VaultFileType.image,
        localPath: '/app/vault_files/1729330000_bukti_pembayaran.jpg',
        fileSizeBytes: 204800,
        mimeType: 'image/jpeg',
        senderName: 'Budi Santoso',
        senderId: 'user-002',
        roomId: 'room-101',
        savedAt: now,
      );

      final map = original.toMap();
      expect(map['id'], 'vault-uuid-001');
      expect(map['file_name'], 'bukti_pembayaran.jpg');
      expect(map['file_type'], 'image');
      expect(map['file_size'], 204800);
      expect(map['sender_name'], 'Budi Santoso');

      final fromMap = VaultItem.fromMap(map);
      expect(fromMap.id, original.id);
      expect(fromMap.fileName, original.fileName);
      expect(fromMap.fileType, original.fileType);
      expect(fromMap.fileSizeBytes, original.fileSizeBytes);
      expect(fromMap.senderName, original.senderName);
    });
  });

  group('VaultScreen Widget Tests', () {
    testWidgets('VaultScreen renders category filter chips and empty state correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultItemsProvider.overrideWith(
              (ref) => MockVaultNotifier([]),
            ),
          ],
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Brankas Berkas'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Gambar'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Dokumen'), findsOneWidget);
      expect(find.text('Brankas Terkunci & Aman'), findsOneWidget);
    });
  });

  group('ArchivedChatsScreen Widget Tests', () {
    testWidgets('ArchivedChatsScreen filters and displays only archived rooms', (
      WidgetTester tester,
    ) async {
      final fakeRooms = [
        {
          'id': 'room-1',
          'name': 'Budi Santoso',
          'lastMessage': 'Halo apa kabar?',
          'timestamp': DateTime(2026, 10, 19, 10, 0),
          'unreadCount': 0,
          'isArchived': false,
          'isGuardian': false,
          'isMuted': false,
        },
        {
          'id': 'room-2',
          'name': 'Proyek Rahasia',
          'lastMessage': 'Dokumen sudah diarsipkan',
          'timestamp': DateTime(2026, 10, 18, 12, 0),
          'unreadCount': 0,
          'isArchived': true,
          'isGuardian': false,
          'isMuted': false,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRoomsProvider.overrideWith(
              (ref) => MockChatRoomsNotifier(fakeRooms),
            ),
          ],
          child: const MaterialApp(
            home: ArchivedChatsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Arsip Percakapan'), findsOneWidget);
      // Room 2 (archived) harus muncul
      expect(find.text('Proyek Rahasia'), findsOneWidget);
      // Room 1 (not archived) TIDAK boleh muncul di layar arsip
      expect(find.text('Budi Santoso'), findsNothing);
    });

    testWidgets('ArchivedChatsScreen renders empty state when no chats are archived', (
      WidgetTester tester,
    ) async {
      final fakeRooms = [
        {
          'id': 'room-1',
          'name': 'Budi Santoso',
          'lastMessage': 'Halo',
          'timestamp': DateTime(2026, 10, 19, 10, 0),
          'unreadCount': 0,
          'isArchived': false,
          'isGuardian': false,
          'isMuted': false,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRoomsProvider.overrideWith(
              (ref) => MockChatRoomsNotifier(fakeRooms),
            ),
          ],
          child: const MaterialApp(
            home: ArchivedChatsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Arsip Bersih'), findsOneWidget);
    });
  });

  group('MekaarPinVerificationSheet Widget Tests', () {
    testWidgets('Shows warning when PIN is not set yet', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final authRepo = ref.watch(authRepositoryProvider);
              final notifier = AuthNotifier(authRepo);
              notifier.state = AuthState(isPinSet: false);
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MekaarPinVerificationSheet(
                title: 'Buka Brankas Berkas',
                subtitle: 'Masukkan PIN untuk melanjutkan',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PIN Keamanan Belum Diatur'), findsOneWidget);
      expect(find.text('Atur PIN Sekarang'), findsOneWidget);
    });
  });
}
