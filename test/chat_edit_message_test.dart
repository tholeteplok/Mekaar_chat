// test/chat_edit_message_test.dart
//
// Suite pengujian komprehensif untuk fitur Edit Pesan Terkirim:
//   - Validasi canEditMessage (teks, batas waktu 30 menit, Guardian, terhapus)
//   - Validasi getEditRestrictionReason (pesan edukasi transparan)
//   - Widget test: tombol Pensil muncul di ChatSelectionAppBar untuk pesan sendiri
//
// Semua tes berjalan tanpa jaringan (unit & widget test murni).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_selection_app_bar.dart';

Message _makeMsg({
  String id = 'msg-001',
  MessageType type = MessageType.text,
  bool isDeleted = false,
  Duration age = Duration.zero,
  String content = 'Halo bro',
}) {
  final created = DateTime.now().toUtc().subtract(age);
  return Message(
    id: id,
    roomId: 'room-001',
    senderId: 'user-001',
    content: content,
    type: type,
    isDeleted: isDeleted,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  final repo = ChatRepository(SupabaseService());

  group('ChatRepository.canEditMessage', () {
    test('A1. Pesan teks milik sendiri berumur < 30 menit -> boleh diedit', () {
      final msg = _makeMsg(age: const Duration(minutes: 5));
      final now = msg.createdAt.add(const Duration(minutes: 5));

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: false,
        now: now,
      );
      expect(canEdit, isTrue);
    });

    test('A2. Pesan teks berumur tepat 30 menit -> masih boleh diedit (batas inklusif)', () {
      final msg = _makeMsg();
      final exactly30 = msg.createdAt.add(const Duration(minutes: 30));

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: false,
        now: exactly30,
      );
      expect(canEdit, isTrue);
    });

    test('A3. Pesan teks berumur 31 menit -> ditolak karena batas waktu', () {
      final msg = _makeMsg();
      final after31 = msg.createdAt.add(const Duration(minutes: 31));

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: false,
        now: after31,
      );
      expect(canEdit, isFalse);
    });

    test('A4. Pesan pada isGuardianRoom: true -> selalu ditolak', () {
      final msg = _makeMsg(age: const Duration(minutes: 2));

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: true,
      );
      expect(canEdit, isFalse);
    });

    test('A5. Pesan yang sudah dihapus -> ditolak', () {
      final msg = _makeMsg(isDeleted: true);

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: false,
      );
      expect(canEdit, isFalse);
    });

    test('A6. Pesan non-teks (gambar) -> ditolak', () {
      final msg = _makeMsg(type: MessageType.image);

      final canEdit = repo.canEditMessage(
        msg,
        isGuardianRoom: false,
      );
      expect(canEdit, isFalse);
    });

    test('A7. Konstanta maxEditWindow tepat 30 menit', () {
      expect(ChatRepository.maxEditWindow, const Duration(minutes: 30));
    });
  });

  group('ChatRepository.getEditRestrictionReason', () {
    test('B1. Room normal, teks, < 30 menit -> null (diizinkan)', () {
      final msg = _makeMsg(age: const Duration(minutes: 5));
      final now = msg.createdAt.add(const Duration(minutes: 5));

      final reason = repo.getEditRestrictionReason(
        msg,
        isGuardianRoom: false,
        now: now,
      );
      expect(reason, isNull);
    });

    test('B2. Room Guardian -> pesan integritas hukum', () {
      final msg = _makeMsg(age: const Duration(minutes: 2));

      final reason = repo.getEditRestrictionReason(
        msg,
        isGuardianRoom: true,
      );
      expect(reason, contains('Guardian'));
      expect(reason, contains('integritas bukti hukum'));
    });

    test('B3. Pesan terhapus -> pesan terhapus', () {
      final msg = _makeMsg(isDeleted: true);

      final reason = repo.getEditRestrictionReason(
        msg,
        isGuardianRoom: false,
      );
      expect(reason, contains('dihapus'));
    });

    test('B4. Pesan gambar -> hanya teks', () {
      final msg = _makeMsg(type: MessageType.image);

      final reason = repo.getEditRestrictionReason(
        msg,
        isGuardianRoom: false,
      );
      expect(reason, contains('teks'));
    });

    test('B5. Pesan lewat 31 menit -> batas waktu berakhir', () {
      final msg = _makeMsg();
      final after31 = msg.createdAt.add(const Duration(minutes: 31));

      final reason = repo.getEditRestrictionReason(
        msg,
        isGuardianRoom: false,
        now: after31,
      );
      expect(reason, contains('30 menit'));
      expect(reason, contains('berakhir'));
    });
  });

  group('ChatSelectionAppBar - tombol Edit (Pensil)', () {
    testWidgets(
      'C1. canEdit: true -> ikon Pensil tampil dan callback berjalan saat diketuk',
      (tester) async {
        bool editTapped = false;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 1,
              canEdit: true,
              canReply: false,
              onEdit: () => editTapped = true,
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ));

        expect(find.byIcon(SolarIconsOutline.pen), findsOneWidget);
        await tester.tap(find.byIcon(SolarIconsOutline.pen));
        await tester.pump();
        expect(editTapped, isTrue);
      },
    );

    testWidgets(
      'C2. canEdit: false -> ikon Pensil tidak muncul',
      (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 2,
              canEdit: false,
              canReply: false,
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ));

        expect(find.byIcon(SolarIconsOutline.pen), findsNothing);
      },
    );

    testWidgets(
      'C3. selectedCount tampil benar',
      (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 3,
              canEdit: false,
              canReply: false,
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ));

        expect(find.text('3 dipilih'), findsOneWidget);
      },
    );

    testWidgets(
      'C4. canEdit: true tapi onEdit null -> tombol tidak ditampilkan',
      (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 1,
              canEdit: true,
              canReply: false,
              onEdit: null,
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ));

        expect(find.byIcon(SolarIconsOutline.pen), findsNothing);
      },
    );
  });
}
