import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/chat_draft_model.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/features/chat/providers/chat_draft_provider.dart';

class SwitchableMockLocalMessageDatabase extends Fake implements LocalMessageDatabase {
  bool isDecoyMode = false;
  final Map<String, ChatDraft> masterStorage = {};
  final Map<String, ChatDraft> decoyStorage = {};

  Map<String, ChatDraft> get _activeStorage => isDecoyMode ? decoyStorage : masterStorage;

  @override
  Future<Map<String, ChatDraft>> getAllDrafts() async => Map.from(_activeStorage);

  @override
  Future<ChatDraft?> getDraft(String roomId) async => _activeStorage[roomId];

  @override
  Future<void> saveDraft(String roomId, String content, {String? replyToId}) async {
    _activeStorage[roomId] = ChatDraft(
      roomId: roomId,
      content: content,
      replyToId: replyToId,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteDraft(String roomId) async {
    _activeStorage.remove(roomId);
  }

  @override
  Future<void> switchMode({required bool isDecoy}) async {
    isDecoyMode = isDecoy;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatDraftsNotifier Memory Isolation & Mode Switch Tests', () {
    test('clearMemoryDrafts() membersihkan seluruh draf di RAM seketika', () {
      final mockDb = SwitchableMockLocalMessageDatabase();
      final notifier = ChatDraftsNotifier(mockDb);

      // 1. Simpan draf volatile di RAM
      notifier.setDraft(
        roomId: 'room_secret_1',
        content: 'Rencana rahasia master',
        isBurnOnExit: true,
      );
      expect(notifier.state.containsKey('room_secret_1'), isTrue);

      // 2. Bersihkan memori RAM
      notifier.clearMemoryDrafts();

      // 3. Verifikasi: state RAM kosong total
      expect(notifier.state.isEmpty, isTrue);
      notifier.dispose();
    });

    test('reloadDrafts() memuat draf segar dari database aktif', () async {
      final mockDb = SwitchableMockLocalMessageDatabase();
      mockDb.masterStorage['room_db_1'] = ChatDraft(
        roomId: 'room_db_1',
        content: 'Draf tersimpan di master',
        updatedAt: DateTime.now(),
      );

      final notifier = ChatDraftsNotifier(mockDb);
      await notifier.reloadDrafts();

      expect(notifier.state.containsKey('room_db_1'), isTrue);
      expect(notifier.state['room_db_1']?.content, equals('Draf tersimpan di master'));
      notifier.dispose();
    });

    test('Isolasi Antar-Sesi: Draf Master di RAM tidak bocor ke sesi Decoy saat beralih mode', () async {
      final mockDb = SwitchableMockLocalMessageDatabase();
      mockDb.isDecoyMode = false;
      mockDb.masterStorage['room_master_alpha'] = ChatDraft(
        roomId: 'room_master_alpha',
        content: 'Informasi keuangan rahasia',
        updatedAt: DateTime.now(),
      );
      mockDb.decoyStorage['room_decoy_casual'] = ChatDraft(
        roomId: 'room_decoy_casual',
        content: 'Beli kopi nanti siang',
        updatedAt: DateTime.now(),
      );

      // Sesi 1: Pengguna masuk dalam mode Master
      final notifier = ChatDraftsNotifier(mockDb);
      await notifier.reloadDrafts();
      expect(notifier.state.containsKey('room_master_alpha'), isTrue);
      expect(notifier.state.containsKey('room_decoy_casual'), isFalse);

      // Skenario: Aplikasi terkunci ke PinScreen
      // Sesuai siklus baru: clearMemoryDrafts dipanggil seketika di initState PinScreen
      notifier.clearMemoryDrafts();
      expect(notifier.state.isEmpty, isTrue);

      // Skenario: Dibuka dengan PIN Tamu (Decoy Mode)
      await mockDb.switchMode(isDecoy: true);
      // Sesuai alur _verifyPin: reloadDrafts membaca database decoy
      await notifier.reloadDrafts();

      // Verifikasi Kritis:
      // Draf Master WAJIB 100% TIDAK TERLIHAT di mode Decoy!
      expect(notifier.state.containsKey('room_master_alpha'), isFalse);
      // Hanya draf Decoy yang tampil
      expect(notifier.state.containsKey('room_decoy_casual'), isTrue);
      expect(notifier.state['room_decoy_casual']?.content, equals('Beli kopi nanti siang'));

      // Skenario Kembali: Pemilik membuka kembali dengan PIN Utama (Master)
      await mockDb.switchMode(isDecoy: false);
      await notifier.reloadDrafts();

      // Draf Master kembali aktif secara aman
      expect(notifier.state.containsKey('room_master_alpha'), isTrue);
      expect(notifier.state.containsKey('room_decoy_casual'), isFalse);

      notifier.dispose();
    });
  });
}
