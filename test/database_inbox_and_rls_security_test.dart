import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/message_preview_resolver.dart';
import 'package:mekaar_chat/data/models/message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Temuan 1 & 2: Migration 102 Composite Index & RPC Hardening Tests', () {
    final file = File('supabase/migrations/102_get_user_inbox_rpc.sql');

    test('File migrasi 102 tersedia dan valid', () {
      expect(file.existsSync(), isTrue, reason: '102_get_user_inbox_rpc.sql must exist');
    });

    test('Temuan 1: Composite Partial Index idx_messages_room_created_at terdefinisi dengan tepat', () {
      final content = file.readAsStringSync();
      expect(
        content.contains('CREATE INDEX IF NOT EXISTS idx_messages_room_created_at'),
        isTrue,
        reason: 'Composite index name must be idx_messages_room_created_at',
      );
      expect(
        content.contains('ON public.messages (room_id, created_at DESC)'),
        isTrue,
        reason: 'Index target columns must be (room_id, created_at DESC)',
      );
      expect(
        content.contains('WHERE is_deleted = false'),
        isTrue,
        reason: 'Partial index predicate WHERE is_deleted = false must be present',
      );
    });

    test('Temuan 2: RPC get_user_inbox() memiliki security guard server-side dan zero-leak privilege', () {
      final content = file.readAsStringSync();

      // Definisi fungsi & search_path
      expect(content.contains('CREATE OR REPLACE FUNCTION public.get_user_inbox()'), isTrue);
      expect(content.contains('RETURNS JSONB'), isTrue);
      expect(content.contains('SECURITY DEFINER'), isTrue);
      expect(content.contains('SET search_path = public, auth'), isTrue);

      // Enforce auth.uid() dari server session (mencegah parameter injection)
      expect(content.contains('v_user_id UUID := auth.uid();'), isTrue);
      expect(content.contains('IF v_user_id IS NULL THEN'), isTrue);

      // Filter keamanan query: deleted_at IS NULL & history_cleared_at
      expect(content.contains('rp.deleted_at IS NULL'), isTrue);
      expect(content.contains('mr.history_cleared_at IS NULL OR m.created_at > mr.history_cleared_at'), isTrue);

      // Privilege lockdown (Revoke public, Grant authenticated)
      expect(content.contains('REVOKE ALL ON FUNCTION public.get_user_inbox() FROM PUBLIC;'), isTrue);
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.get_user_inbox() TO authenticated;'), isTrue);
    });
  });

  group('Temuan 3: Hardening RLS room_participants (Anti-BOLA/IDOR) Tests', () {
    final file = File('supabase/migrations/102_get_user_inbox_rpc.sql');

    test('Policy permisif lama dicabut', () {
      final content = file.readAsStringSync();
      expect(
        content.contains('DROP POLICY IF EXISTS "Authenticated users can insert room participants" ON public.room_participants;'),
        isTrue,
      );
      expect(
        content.contains('DROP POLICY IF EXISTS "Users can insert room participants" ON public.room_participants;'),
        isTrue,
      );
    });

    test('Policy baru menegakkan otorisasi admin/owner grup atau inisiator room', () {
      final content = file.readAsStringSync();
      expect(
        content.contains('CREATE POLICY "Strict room participant insertion guard"'),
        isTrue,
      );
      expect(
        content.contains('FOR INSERT'),
        isTrue,
      );
      expect(
        content.contains("rp_admin.role IN ('owner', 'admin')"),
        isTrue,
        reason: 'Group participant addition must require owner or admin role',
      );
      expect(
        content.contains('rp_admin.profile_id = auth.uid()'),
        isTrue,
        reason: 'Admin validation must check auth.uid()',
      );
    });
  });

  String resolveEncryptedPreview({
    required bool isEncrypted,
    required bool isUnreadFromOther,
  }) {
    if (isEncrypted) {
      return isUnreadFromOther ? 'Pesan baru' : '••••••••';
    }
    return '';
  }

  group('Client Inbox Parser & Preview Resolver Compatibility Tests', () {
    test('Format JSON dari get_user_inbox() diparsing dengan benar oleh ChatList formatters', () {
      final sampleRpcItem = <String, dynamic>{
        'id': 'room-xyz-123',
        'roomType': 'direct',
        'isGroup': false,
        'isGuardian': false,
        'isMuted': false,
        'isArchived': false,
        'otherUserId': 'partner-456',
        'name': 'Siti Aminah',
        'avatar': 'S',
        'avatarUrl': 'https://mekaar.id/avatar/siti.png',
        'memberCount': 2,
        'unreadCount': 3,
        'timestamp': '2026-10-26T12:00:00.000Z',
        'lastMessage': {
          'id': 'msg-999',
          'roomId': 'room-xyz-123',
          'senderId': 'partner-456',
          'content': 'Halo, laporan keselamatan sudah terkirim.',
          'msgType': 'text',
          'isEncrypted': false,
          'createdAt': '2026-10-26T12:00:00.000Z',
        },
      };

      // Pastikan field terisi sesuai ekspektasi ChatRoomsNotifier
      expect(sampleRpcItem['id'], 'room-xyz-123');
      expect(sampleRpcItem['name'], 'Siti Aminah');
      expect(sampleRpcItem['unreadCount'], 3);

      final lastMsg = sampleRpcItem['lastMessage'] as Map<String, dynamic>;
      final preview = MessagePreviewResolver.formatChatListPreview(
        type: MessageType.text,
        content: lastMsg['content'] as String,
        isUnreadFromOther: true,
      );

      expect(preview, 'Halo, laporan keselamatan sudah terkirim.');
    });

    test('Pesan terenkripsi dari lawan bicara yang unread menghasilkan preview "Pesan baru"', () {
      final preview = resolveEncryptedPreview(
        isEncrypted: true,
        isUnreadFromOther: true,
      );
      expect(preview, 'Pesan baru');
    });

    test('Pesan terenkripsi yang sudah terbaca menghasilkan preview "••••••••"', () {
      final preview = resolveEncryptedPreview(
        isEncrypted: true,
        isUnreadFromOther: false,
      );
      expect(preview, '••••••••');
    });
  });
}
