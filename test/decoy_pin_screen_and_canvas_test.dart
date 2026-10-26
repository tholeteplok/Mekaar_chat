import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/mekaar_canvas.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_list_tile.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/widgets/emergency_active_banner.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  @override
  Future<SOSSession?> getActiveSOS() async => null;
}

class FakeSOSNotifier extends SOSNotifier {
  FakeSOSNotifier([SOSState? initial]) : super(MockSOSRepository()) {
    if (initial != null) state = initial;
  }
}

class MockAuthRepository extends Fake implements AuthRepository {
  @override
  Future<bool> validatePIN(String pin) async => pin == '123456';
  @override
  Future<bool> validateDecoyPIN(String pin) async => pin == '654321';
  @override
  Future<bool> validateDuressPIN(String pin) async => pin == '999999';
  @override
  Future<void> clearPinLockout() async {}
  @override
  Future<void> saveUnlockMode(String mode) async {}
  @override
  Future<DateTime> getServerTime() async => DateTime.now();
  @override
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Decoy Room Data Schema & Compatibility Tests', () {
    test('LocalMessageDatabase.getDecoyRooms() mengembalikan struktur camelCase dan snake_case lengkap', () async {
      final rooms = await LocalMessageDatabase.instance.getDecoyRooms();
      expect(rooms, isNotEmpty);

      final room = rooms.first;
      // Validasi camelCase fields yang dibutuhkan ChatListScreen & ChatListTile
      expect(room['id'], equals('room_welcome_mekaar'));
      expect(room['name'], equals('Mekaar Official'));
      expect(room['avatar'], equals('M'));
      expect(room['lastMessage'], isA<String>());
      expect(room['timestamp'], isA<DateTime>());
      expect(room['unreadCount'], equals(0));
      expect(room['isGuardian'], isFalse);
      expect(room['isGroup'], isFalse);
      expect(room['otherUserId'], equals('mekaar_official'));

      // Validasi fallback backward compatibility keys
      expect(room['room_id'], equals('room_welcome_mekaar'));
      expect(room['chat_name'], equals('Mekaar Official'));
      expect(room['last_message'], isA<String>());
      expect(room['other_user_id'], equals('mekaar_official'));
    });
  });

  group('ChatListTile Robustness & Grey Screen Prevention Tests', () {
    testWidgets('ChatListTile merender decoy room tanpa melempar TypeError', (tester) async {
      final rooms = await LocalMessageDatabase.instance.getDecoyRooms();
      final room = rooms.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: room,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Pastikan nama dan cuplikan pesan terender
      expect(find.text('Mekaar Official'), findsOneWidget);
      expect(find.textContaining('Selamat datang di Mekaar Chat!'), findsOneWidget);
    });

    testWidgets('ChatListTile menangani lastMessage bertipe Message object tanpa crash', (tester) async {
      final legacyRoom = {
        'id': 'room-legacy-123',
        'name': 'Kontak Tes',
        'timestamp': DateTime.now(),
        'unreadCount': 1,
        'lastMessage': Message(
          id: 'msg-test-1',
          roomId: 'room-legacy-123',
          senderId: 'user-sender',
          content: 'Pesan objek Message sukses ditangani',
          type: MessageType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: legacyRoom,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kontak Tes'), findsOneWidget);
      expect(find.text('Pesan objek Message sukses ditangani'), findsOneWidget);
    });

    testWidgets('ChatListTile menangani fallback legacy keys (room_id, chat_name, last_message)', (tester) async {
      final legacyRoom = {
        'room_id': 'room-snake-456',
        'chat_name': 'Kontak Snake Case',
        'timestamp': DateTime.now(),
        'unread_count': 0,
        'last_message': 'Pesan dari field last_message',
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatListTile(
                room: legacyRoom,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kontak Snake Case'), findsOneWidget);
      expect(find.text('Pesan dari field last_message'), findsOneWidget);
    });
  });

  group('MekaarCanvas & EmergencyActiveBanner Stealth Hardening Tests', () {
    testWidgets('MekaarCanvas tidak menampilkan kanvas merah SOS saat mode decoy aktif', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(MockAuthRepository())
              ..state = AuthState(unlockMode: AuthUnlockMode.decoy),
          ),
          sosProvider.overrideWith(
            (ref) => FakeSOSNotifier(SOSState(status: SOSStatus.active)),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MekaarCanvas(
              child: Text('Konten Normal'),
            ),
          ),
        ),
      );

      expect(find.text('Konten Normal'), findsOneWidget);

      // Verifikasi bahwa latar belakang BUKAN AppColors.sosDeep
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasRedSosBackground = containers.any(
        (c) => c.color == AppColors.sosDeep,
      );
      expect(hasRedSosBackground, isFalse, reason: 'Decoy mode must not render SOS red canvas');
    });

    testWidgets('EmergencyActiveBanner tersembunyi sepenuhnya saat mode decoy aktif', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier(MockAuthRepository())
              ..state = AuthState(unlockMode: AuthUnlockMode.decoy),
          ),
          sosProvider.overrideWith(
            (ref) => FakeSOSNotifier(SOSState(status: SOSStatus.active)),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EmergencyActiveBanner(),
            ),
          ),
        ),
      );

      // Banner tidak boleh muncul saat mode Decoy (PIN Tamu) aktif
      expect(find.text('Mode Darurat SOS Aktif'), findsNothing);
      expect(find.text('SOS Tertunda Offline'), findsNothing);
    });
  });
}
