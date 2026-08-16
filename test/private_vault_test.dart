import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateContactRepository & Vault Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Passcode belum diatur pada inisialisasi awal', () async {
      final repo = PrivateContactRepository();
      final hasCode = await repo.hasPasscode();
      expect(hasCode, isFalse);
    });

    test('Set passcode berhasil dan terverifikasi dengan benar', () async {
      final repo = PrivateContactRepository();
      await repo.setPasscode('secret777');

      final hasCode = await repo.hasPasscode();
      expect(hasCode, isTrue);

      final isMatch = await repo.verifyPasscode('secret777');
      expect(isMatch, isTrue);

      final isWrong = await repo.verifyPasscode('wrong123');
      expect(isWrong, isFalse);

      final isEmpty = await repo.verifyPasscode('');
      expect(isEmpty, isFalse);
    });

    test('Penyembunyian room (Cloaking) dan pembatalan penyembunyian', () async {
      final repo = PrivateContactRepository();
      const roomId = 'room_xyz_123';

      expect(await repo.isRoomHidden(roomId), isFalse);

      // Sembunyikan room
      final isHiddenFirst = await repo.toggleHideRoom(roomId);
      expect(isHiddenFirst, isTrue);
      expect(await repo.isRoomHidden(roomId), isTrue);

      final hiddenList = await repo.getHiddenRoomIds();
      expect(hiddenList.contains(roomId), isTrue);

      // Batalkan sembunyikan room
      final isHiddenSecond = await repo.toggleHideRoom(roomId);
      expect(isHiddenSecond, isFalse);
      expect(await repo.isRoomHidden(roomId), isFalse);
    });

    test('HiddenRoomIdsNotifier bereaksi terhadap perubahan toggle', () async {
      final repo = PrivateContactRepository();
      final notifier = HiddenRoomIdsNotifier(repo);

      await notifier.loadHiddenRooms();
      expect(notifier.state.isEmpty, isTrue);

      const roomId = 'room_secret_999';
      final isNowHidden = await notifier.toggleHide(roomId);
      expect(isNowHidden, isTrue);
      expect(notifier.state.contains(roomId), isTrue);
      expect(notifier.isHidden(roomId), isTrue);

      final isUnhidden = await notifier.toggleHide(roomId);
      expect(isUnhidden, isFalse);
      expect(notifier.state.contains(roomId), isFalse);
      expect(notifier.isHidden(roomId), isFalse);
    });
  });
}
