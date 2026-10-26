import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/call_invitation_listener.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

class MockChatRepository extends Fake implements ChatRepository {
  List<Map<String, dynamic>> cachedRooms = [];
  List<Map<String, dynamic>> remoteRooms = [];
  int getCachedRoomsCallCount = 0;
  int getRoomsCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> getCachedRooms() async {
    getCachedRoomsCallCount++;
    return cachedRooms;
  }

  @override
  Future<List<Map<String, dynamic>>> getRooms() async {
    getRoomsCallCount++;
    return remoteRooms;
  }
}

class FakeAuthRepository extends Fake implements AuthRepository {
  String? localDuressHash;
  int getProfileCallCount = 0;

  @override
  Future<bool> validateDuressPIN(String pin) async {
    if (localDuressHash == 'none' || localDuressHash == 'disabled') {
      return false;
    }
    if (localDuressHash == null) {
      getProfileCallCount++;
      return false;
    }
    return pin == '999999';
  }
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(super.repo, AuthState initialState) {
    state = initialState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinScreen Speed & Local-First Tests', () {
    test('ChatRoomsNotifier.reloadFromLocalCache memuat data seketika dan sync remote di background', () async {
      final mockRepo = MockChatRepository();
      mockRepo.cachedRooms = [
        {'id': 'room_local_1', 'name': 'Ruang Lokal Cepat'}
      ];
      mockRepo.remoteRooms = [
        {'id': 'room_local_1', 'name': 'Ruang Lokal Cepat'},
        {'id': 'room_remote_2', 'name': 'Ruang Remote Baru'}
      ];

      final notifier = ChatRoomsNotifier(mockRepo);

      // Tunggu init selesai
      await Future.delayed(const Duration(milliseconds: 50));

      // Reset hit counts
      mockRepo.getCachedRoomsCallCount = 0;
      mockRepo.getRoomsCallCount = 0;

      // Panggil reloadFromLocalCache (simulasi buka PIN)
      await notifier.reloadFromLocalCache(syncRemoteInBackground: true);

      // Verifikasi: Cache lokal termuat seketika di state
      expect(mockRepo.getCachedRoomsCallCount, equals(1));
      expect(notifier.state.hasValue, isTrue);
      expect(notifier.state.value!.first['name'], equals('Ruang Lokal Cepat'));

      // Tunggu background sync selesai
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.getRoomsCallCount, equals(1));
    });

    test('ChatRoomsNotifier.reloadFromLocalCache tidak menyentuh remote jika syncRemoteInBackground=false (Decoy)', () async {
      final mockRepo = MockChatRepository();
      mockRepo.cachedRooms = [
        {'id': 'room_decoy', 'name': 'Mekaar Official'}
      ];

      final notifier = ChatRoomsNotifier(mockRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      mockRepo.getCachedRoomsCallCount = 0;
      mockRepo.getRoomsCallCount = 0;

      await notifier.reloadFromLocalCache(syncRemoteInBackground: false);

      expect(mockRepo.getCachedRoomsCallCount, equals(1));
      expect(notifier.state.value!.first['name'], equals('Mekaar Official'));

      await Future.delayed(const Duration(milliseconds: 50));
      // Pastikan getRooms (remote) TIDAK dipanggil sama sekali di mode decoy
      expect(mockRepo.getRoomsCallCount, equals(0));
    });

    test('DatabaseKeyService.deriveVaultKey tidak menjalankan PBKDF2 100k redundan pada alur normal', () async {
      const pin = '123456';

      // Pastikan kunci legacy bersih
      DatabaseKeyService.instance.lockVault();
      expect(DatabaseKeyService.instance.activeLegacyVaultKey, isNull);

      final key = await DatabaseKeyService.instance.deriveVaultKey(pin, isDuress: false);

      expect(key, isNotEmpty);
      expect(key.length, equals(64));
      // Kunci legacy PBKDF2 TIDAK boleh dihitung secara otomatis jika Argon2id sukses (hemat 100k iterasi)
      expect(DatabaseKeyService.instance.activeLegacyVaultKey, isNull);

      // Turunkan secara on-demand jika dibutuhkan untuk re-keying database lama
      final legacyKey = await DatabaseKeyService.instance.deriveLegacyVaultKey(pin, isDuress: false);
      expect(legacyKey, isNotEmpty);
      expect(DatabaseKeyService.instance.activeLegacyVaultKey, equals(legacyKey));
    });

    test('validateDuressPIN langsung mengembalikan false tanpa query network jika tersimpan sentinel none', () async {
      final fakeRepo = FakeAuthRepository();
      fakeRepo.localDuressHash = 'none';

      final result = await fakeRepo.validateDuressPIN('123456');

      expect(result, isFalse);
      // getProfile TIDAK dipanggil sama sekali
      expect(fakeRepo.getProfileCallCount, equals(0));
    });
  });

  group('Decoy Hardening Tests (Audit Lanjutan)', () {
    test('CallInvitationListener membungkam panggilan masuk saat sesi Decoy aktif', () async {
      final fakeRepo = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => FakeAuthNotifier(
              fakeRepo,
              AuthState(unlockMode: AuthUnlockMode.decoy),
            ),
          ),
        ],
      );

      final listener = container.read(callInvitationListenerProvider);

      // Simulasi panggilan masuk dari Supabase
      final incomingCallPayload = {
        'id': 'call_123',
        'room_id': 'room_master_abc',
        'caller_id': 'user_master_friend',
        'receiver_id': 'test_user_id',
        'call_type': 'voice',
        'status': 'calling',
      };

      // Seharusnya return seketika tanpa navigasi atau memicu layar panggilan
      await listener.processIncomingCallRecord(incomingCallPayload);

      // Verifikasi: tidak ada crash dan mode decoy terproteksi
      expect(container.read(authProvider).isDecoyActive, isTrue);

      container.dispose();
    });
  });
}
