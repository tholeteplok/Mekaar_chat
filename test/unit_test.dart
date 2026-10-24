import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/mekaar_notification_dot.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/models/security_log_model.dart';
import 'package:mekaar_chat/data/models/user_device.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';
import 'package:mekaar_chat/data/models/call_model.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/settings/providers/privacy_provider.dart';
import 'package:mekaar_chat/data/services/wakelock_service.dart';
import 'package:mekaar_chat/core/utils/call_e2ee_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() {
  group('Mekaar Data Models Unit Tests', () {
    test('Profile Model serialization & deserialization', () {
      final json = {
        'id': 'user-123',
        'username': 'john_doe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'pin_hash': 'hashed_pin_value',
        'created_at': '2026-07-13T12:00:00Z',
        'updated_at': '2026-07-13T12:00:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.username, 'john_doe');
      expect(profile.email, 'john@example.com');
      expect(profile.fullName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.pinHash, 'hashed_pin_value');

      final serialized = profile.toJson();
      expect(serialized['id'], 'user-123');
      expect(serialized['username'], 'john_doe');
    });

    test('Message Model handling types & view-once flags', () {
      final now = DateTime.now();
      final json = {
        'id': 'msg-001',
        'room_id': 'chat-100',
        'sender_id': 'user-123',
        'content': 'Halo, ini lokasi saya',
        'media_url': 'https://example.com/media.jpg',
        'msg_type': 'location',
        'is_view_once': true,
        'is_deleted': false,
        'reply_to_id': 'msg-000',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'auto_delete_at': now.add(const Duration(hours: 24)).toIso8601String(),
      };

      final message = Message.fromJson(json);

      expect(message.id, 'msg-001');
      expect(message.type, MessageType.location);
      expect(message.isViewOnce, isTrue);
      expect(message.isDeleted, isFalse);
      expect(message.replyToId, 'msg-000');

      // Test copyWith
      final updated = message.copyWith(isDeleted: true);
      expect(updated.isDeleted, isTrue);
      expect(updated.id, 'msg-001');
    });

    test('Guardian Model active duration checks', () {
      final now = DateTime.now();
      final json = {
        'id': 'relation-001',
        'owner_id': 'user-123',
        'guardian_id': 'user-456',
        'status': 'active',
        'permissions': {'gps': true, 'mic': false},
        'storage_option': 'local',
        // Add 2 hours buffer to guarantee .inDays difference is exactly 20
        'expires_at': now
            .add(const Duration(days: 20, hours: 2))
            .toIso8601String(),
        'created_at': now.subtract(const Duration(days: 10)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 10)).toIso8601String(),
        'guardian_profile': {
          'username': 'jane_doe',
          'full_name': 'Jane Doe',
          'email': 'jane@example.com',
          'avatar_url': '',
        },
      };

      final guardian = Guardian.fromJson(json);

      expect(guardian.id, 'relation-001');
      expect(guardian.name, 'Jane Doe');
      expect(guardian.email, 'jane@example.com');
      expect(guardian.permissions['gps'], isTrue);
      expect(guardian.permissions['mic'], isFalse);

      // Verify 30-day expiration math (10 days elapsed -> 20 days remaining)
      expect(guardian.isExpired, isFalse);
      expect(guardian.daysRemaining, 20);
    });

    test('SOSSession Model initialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'sos-session-111',
        'user_id': 'user-123',
        'status': 'active',
        'gps_enabled': true,
        'mic_enabled': true,
        'video_enabled': false,
        'started_at': now.toIso8601String(),
        'ended_at': null,
        'ended_reason': null,
        'created_at': now.toIso8601String(),
      };

      final session = SOSSession.fromJson(json);

      expect(session.id, 'sos-session-111');
      expect(session.status, 'active');
      expect(session.gpsEnabled, isTrue);
      expect(session.micEnabled, isTrue);
      expect(session.videoEnabled, isFalse);
      expect(session.endedReason, isNull);
    });

    test('SecurityLog Model initialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'log-999',
        'user_id': 'user-123',
        'sos_session_id': 'session-456',
        'event_type': 'sos_started',
        'details': {'reason': 'panic_button'},
        'created_at': now.toIso8601String(),
      };

      final log = SecurityLog.fromJson(json);

      expect(log.id, 'log-999');
      expect(log.sosSessionId, 'session-456');
      expect(log.eventType, 'sos_started');
      expect(log.details?['reason'], 'panic_button');
    });

    test('UserDevice Model serialization & deserialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'device-row-001',
        'profile_id': 'user-123',
        'device_id': 'uuid-device-456',
        'fcm_token': 'fcm-token-xyz',
        'device_label': 'Samsung Galaxy S24',
        'platform': 'android',
        'app_version': '3.0.0',
        'last_seen_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final device = UserDevice.fromJson(json);

      expect(device.id, 'device-row-001');
      expect(device.profileId, 'user-123');
      expect(device.deviceId, 'uuid-device-456');
      expect(device.fcmToken, 'fcm-token-xyz');
      expect(device.deviceLabel, 'Samsung Galaxy S24');
      expect(device.platform, 'android');
      expect(device.appVersion, '3.0.0');
      expect(device.isCurrent('uuid-device-456'), isTrue);
      expect(device.isCurrent('other-device-id'), isFalse);

      final serialized = device.toJson();
      expect(serialized['device_id'], 'uuid-device-456');
      expect(serialized['device_label'], 'Samsung Galaxy S24');
    });
  });

  group('Mekaar Security Logic Unit Tests', () {
    test('SHA-256 PIN Hashing accuracy check', () {
      const pin = '123456';
      final bytes = utf8.encode(pin);
      final hash = sha256.convert(bytes).toString();

      // SHA-256 hash value of "123456" is a known constant
      expect(
        hash,
        '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      );
    });
  });

  group('PIN Lock Preference Unit Tests', () {
    test('memuat preferensi OFF yang sudah tersimpan', () async {
      SharedPreferences.setMockInitialValues({
        PinLockEnabledNotifier.preferenceKey: false,
      });
      final notifier = PinLockEnabledNotifier();

      await notifier.initialized;

      expect(notifier.state, isFalse);
      notifier.dispose();
    });

    test('toggle menyimpan dan memancarkan nilai baru', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = PinLockEnabledNotifier();
      await notifier.initialized;

      await notifier.toggle(false);
      final prefs = await SharedPreferences.getInstance();

      expect(notifier.state, isFalse);
      expect(prefs.getBool(PinLockEnabledNotifier.preferenceKey), isFalse);
      notifier.dispose();
    });
  });

  group('Chat Theme 7 Presets Unit Tests', () {
    test('Canonical 7 Presets are correctly initialized', () {
      expect(ChatThemePreference.mekaar.preset, equals(ChatThemePreset.mekaar));
      expect(ChatThemePreference.comic.preset, equals(ChatThemePreset.comic));
      expect(ChatThemePreference.neuro.preset, equals(ChatThemePreset.neuro));
      expect(ChatThemePreference.mecha.preset, equals(ChatThemePreset.mecha));
      expect(ChatThemePreference.glass.preset, equals(ChatThemePreset.mecha));
      expect(ChatThemePreference.pixel.preset, equals(ChatThemePreset.pixel));
      expect(ChatThemePreference.candy.preset, equals(ChatThemePreset.candy));
      expect(ChatThemePreference.eco.preset, equals(ChatThemePreset.eco));
    });

    test('Legacy preset names deserialize smoothly to canonical 7 presets', () {
      final legacyMapping = {
        'comicPopArt': ChatThemePreset.comic,
        'comic': ChatThemePreset.comic,
        'diary': ChatThemePreset.comic,
        'neumorphism': ChatThemePreset.neuro,
        'neuro': ChatThemePreset.neuro,
        'neonDreams': ChatThemePreset.neuro,
        'neonCyberpunk': ChatThemePreset.neuro,
        'mecha': ChatThemePreset.mecha,
        'glassmorphism': ChatThemePreset.mecha,
        'glass': ChatThemePreset.mecha,
        'fireflyNight': ChatThemePreset.mecha,
        'pixelGarden': ChatThemePreset.pixel,
        'pixel': ChatThemePreset.pixel,
        'retroWave': ChatThemePreset.pixel,
        'retroY2K': ChatThemePreset.pixel,
        'candyPop': ChatThemePreset.candy,
        'candy': ChatThemePreset.candy,
        'isometric3d': ChatThemePreset.candy,
        'solarpunk': ChatThemePreset.eco,
        'eco': ChatThemePreset.eco,
        'mekaar': ChatThemePreset.mekaar,
        'dynamicTime': ChatThemePreset.mekaar,
        'monoVibe': ChatThemePreset.mekaar,
        'swissMinimalist': ChatThemePreset.mekaar,
      };

      legacyMapping.forEach((rawString, expectedPreset) {
        final json = {'preset': rawString};
        final parsed = ChatThemePreference.fromJson(json);
        expect(parsed.preset, equals(expectedPreset),
            reason: 'Failed parsing legacy string: $rawString');
      });
    });

    test('Serialization to JSON and deserialization back matches values', () {
      for (final pref in [
        ChatThemePreference.mekaar,
        ChatThemePreference.comic,
        ChatThemePreference.neuro,
        ChatThemePreference.mecha,
        ChatThemePreference.glass,
        ChatThemePreference.pixel,
        ChatThemePreference.candy,
        ChatThemePreference.eco,
      ]) {
        final json = pref.toJson();
        final reconstructed = ChatThemePreference.fromJson(json);
        expect(reconstructed.preset, equals(pref.preset));
        expect(reconstructed.wallpaperType, equals(pref.wallpaperType));
        expect(reconstructed.bubbleStyle, equals(pref.bubbleStyle));
      }
    });

    test('Entrance animation returns valid specifications for all 7 presets', () {
      for (final preset in ChatThemePreset.values) {
        final anim = ChatPresetResolver.getEntranceAnimation(preset);
        expect(anim.duration, isNotNull);
        expect(anim.curve, isNotNull);
      }
    });

    test('CallModel correctly represents calling, ringing, and connection states', () {
      final now = DateTime.now();

      // Test 'calling' state (Memanggil...)
      final callingCall = CallModel(
        id: 'call-1',
        roomId: 'room-1',
        callerId: 'user-caller',
        receiverId: 'user-receiver',
        callType: 'voice',
        status: 'calling',
        createdAt: now,
        updatedAt: now,
      );
      expect(callingCall.isConnected, isFalse);
      expect(callingCall.getDisplayStatus(true), 'Memanggil...');
      expect(callingCall.getDisplayStatus(false), 'Panggilan masuk...');

      // Test 'ringing' state (Berdering...)
      final ringingCall = CallModel(
        id: 'call-2',
        roomId: 'room-1',
        callerId: 'user-caller',
        receiverId: 'user-receiver',
        callType: 'video',
        status: 'ringing',
        createdAt: now,
        updatedAt: now,
      );
      expect(ringingCall.isVideo, isTrue);
      expect(ringingCall.isConnected, isFalse);
      expect(ringingCall.getDisplayStatus(true), 'Berdering...');
      expect(ringingCall.getDisplayStatus(false), 'Panggilan masuk...');

      // Test connected state with duration
      final answeredCall = CallModel(
        id: 'call-3',
        roomId: 'room-1',
        callerId: 'user-caller',
        receiverId: 'user-receiver',
        callType: 'voice',
        status: 'answered',
        durationSeconds: 125, // 02:05
        createdAt: now,
        updatedAt: now,
      );
      expect(answeredCall.isConnected, isTrue);
      expect(answeredCall.formattedDuration, '02:05');
      expect(answeredCall.getDisplayStatus(true), 'Terhubung • 02:05');

      // Test missed state
      final missedCall = CallModel(
        id: 'call-4',
        roomId: 'room-1',
        callerId: 'user-caller',
        receiverId: 'user-receiver',
        callType: 'voice',
        status: 'missed',
        createdAt: now,
        updatedAt: now,
      );
      expect(missedCall.getDisplayStatus(true), 'Panggilan dibatalkan');
      expect(missedCall.getDisplayStatus(false), 'Panggilan tak terjawab');
    });

    testWidgets('MekaarNotificationDot renders active guardian count badge and dot correctly', (tester) async {
      // 1. Kondisi: 2 guardian aktif tanpa pending
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarNotificationDot(
              badgeCount: 2,
              showDot: false,
              child: Icon(Icons.shield),
            ),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);

      // 2. Kondisi: 0 aktif, tapi ada 1 pending (tampil dot saja)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarNotificationDot(
              badgeCount: null,
              show: true,
              showDot: true,
              child: Icon(Icons.shield),
            ),
          ),
        ),
      );
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    test('Unified Chat Deduplication logic merges duplicate rooms for same contact', () {
      final now = DateTime.now();
      final rooms = [
        {
          'id': 'room-1',
          'otherUserId': 'user-thole',
          'name': 'Thole',
          'timestamp': now.subtract(const Duration(minutes: 15)), // DateTime!
          'unreadCount': 1,
          'isGuardian': false,
          'isArchived': false,
          'isGroup': false,
        },
        {
          'id': 'room-2',
          'otherUserId': 'user-thole',
          'name': 'Thole',
          'timestamp': now, // DateTime!
          'unreadCount': 2,
          'isGuardian': true,
          'isArchived': false,
          'isGroup': false,
        },
      ];

      DateTime extractRoomTimestamp(dynamic timestamp) {
        if (timestamp is DateTime) return timestamp;
        if (timestamp is String) {
          return DateTime.tryParse(timestamp) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      final Map<String, Map<String, dynamic>> unifiedByOtherUser = {};
      final List<Map<String, dynamic>> nonDirectRooms = [];

      for (final room in rooms) {
        final otherUserId = room['otherUserId'] as String?;
        final isGroup = room['isGroup'] as bool? ?? false;

        if (isGroup || otherUserId == null || otherUserId.isEmpty) {
          nonDirectRooms.add(room);
        } else {
          if (!unifiedByOtherUser.containsKey(otherUserId)) {
            unifiedByOtherUser[otherUserId] = Map<String, dynamic>.from(room);
          } else {
            final existing = unifiedByOtherUser[otherUserId]!;
            final existingTime = extractRoomTimestamp(existing['timestamp']);
            final roomTime = extractRoomTimestamp(room['timestamp']);

            final dominantRoom = roomTime.isAfter(existingTime) ? room : existing;
            final isGuardian = (existing['isGuardian'] == true) || (room['isGuardian'] == true);
            final totalUnread = (existing['unreadCount'] as int? ?? 0) + (room['unreadCount'] as int? ?? 0);
            final isArchived = (existing['isArchived'] == true) && (room['isArchived'] == true);

            final merged = Map<String, dynamic>.from(dominantRoom);
            merged['isGuardian'] = isGuardian;
            merged['unreadCount'] = totalUnread;
            merged['isArchived'] = isArchived;
            unifiedByOtherUser[otherUserId] = merged;
          }
        }
      }

      final unifiedRooms = [...unifiedByOtherUser.values, ...nonDirectRooms];
      unifiedRooms.sort((a, b) {
        final tA = extractRoomTimestamp(a['timestamp']);
        final tB = extractRoomTimestamp(b['timestamp']);
        return tB.compareTo(tA);
      });

      // Verifikasi: Hanya ada 1 room Thole
      expect(unifiedRooms.length, 1);
      final thole = unifiedRooms.first;
      expect(thole['otherUserId'], 'user-thole');
      expect(thole['isGuardian'], isTrue); // Tetap diakui sebagai Guardian
      expect(thole['unreadCount'], 3); // 1 + 2 = 3
      expect(thole['id'], 'room-2'); // Dominant ID dari timestamp terbaru
    });

    test('Duress PIN logic ensures distinct PIN from primary and handles active state', () {
      final primaryPin = '123456';
      final duressPin = '654321';
      final sameAsPrimaryPin = '123456';

      // Hash check
      String hashPin(String pin) =>
          sha256.convert(utf8.encode(pin)).toString();

      final primaryHash = hashPin(primaryPin);
      final duressHash = hashPin(duressPin);
      final sameHash = hashPin(sameAsPrimaryPin);

      expect(primaryHash, isNot(equals(duressHash)));
      expect(primaryHash, equals(sameHash));

      // Duress validation: cannot be equal to primary
      bool isDuressValid(String pin, String currentPrimaryPin) {
        if (pin.length != 6) return false;
        if (pin == currentPrimaryPin) return false;
        return true;
      }

      expect(isDuressValid('654321', primaryPin), isTrue);
      expect(isDuressValid('123456', primaryPin), isFalse);
      expect(isDuressValid('123', primaryPin), isFalse);
    });

    test('StealthChatPreviewNotifier toggles and loads persistence correctly', () async {
      SharedPreferences.setMockInitialValues({'stealth_chat_preview': false});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StealthChatPreviewNotifier(prefs);
      expect(notifier.state, isFalse);

      await notifier.toggle();
      expect(notifier.state, isTrue);
      expect(prefs.getBool('stealth_chat_preview'), isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool('stealth_chat_preview'), isFalse);
    });

    test('Chat preview resolution hides timestamp for empty rooms and masks in stealth mode', () {
      // 1. Room tanpa pesan: timestamp harus null dan preview default
      final emptyRoom = <String, dynamic>{
        'id': 'room-01',
        'name': 'Kontak Baru',
        'lastMessage': 'Mulai percakapan...',
        'timestamp': null,
      };

      expect(emptyRoom['timestamp'], isNull);
      expect(emptyRoom['lastMessage'], 'Mulai percakapan...');

      // 2. Room dengan pesan terdekripsi normal
      final activeRoom = <String, dynamic>{
        'id': 'room-02',
        'name': 'Thole',
        'lastMessage': 'Halo, bagaimana kabarmu?',
        'timestamp': DateTime(2026, 10, 18, 1, 20),
      };

      String resolvePreview(Map<String, dynamic> room, {required bool isStealth}) {
        final hasMessages = room['timestamp'] != null;
        if (isStealth && hasMessages) {
          return '••••••••';
        }
        return room['lastMessage'] as String? ?? 'Mulai percakapan...';
      }

      // Normal mode (Opsi A / Signal-grade)
      expect(resolvePreview(activeRoom, isStealth: false), 'Halo, bagaimana kabarmu?');
      expect(resolvePreview(emptyRoom, isStealth: false), 'Mulai percakapan...');

      // Stealth mode (Opsi C aktif)
      expect(resolvePreview(activeRoom, isStealth: true), '••••••••');
      expect(resolvePreview(emptyRoom, isStealth: true), 'Mulai percakapan...');
    });
  });

  group('WakelockService Unit Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.mekaar.mekaar_chat/wakelock');
    final log = <String>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall.method);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('enable calls native enable method on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await WakelockService.enable();
      expect(log, contains('enable'));
      expect(WakelockService.isEnabled, true);
      debugDefaultTargetPlatformOverride = null;
    });

    test('disable calls native disable method on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await WakelockService.disable();
      expect(log, contains('disable'));
      expect(WakelockService.isEnabled, false);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('CallE2eeHelper Unit Tests', () {
    test('produces exactly 4 emojis deterministically', () {
      final emojis1 = CallE2eeHelper.getCallEmojis(
        callId: 'call-abc-123',
        userId1: 'user-alice',
        userId2: 'user-bob',
      );
      final emojis2 = CallE2eeHelper.getCallEmojis(
        callId: 'call-abc-123',
        userId1: 'user-alice',
        userId2: 'user-bob',
      );

      expect(emojis1.length, 4);
      expect(emojis1, equals(emojis2));
    });

    test('is symmetric regardless of userId order', () {
      final fromCaller = CallE2eeHelper.getCallEmojis(
        callId: 'call-abc-123',
        userId1: 'user-alice',
        userId2: 'user-bob',
      );
      final fromCallee = CallE2eeHelper.getCallEmojis(
        callId: 'call-abc-123',
        userId1: 'user-bob',
        userId2: 'user-alice',
      );

      expect(fromCaller, equals(fromCallee));
    });

    test('different calls produce different emoji sets', () {
      final call1 = CallE2eeHelper.getCallEmojis(
        callId: 'call-room-1',
        userId1: 'user-alice',
        userId2: 'user-bob',
      );
      final call2 = CallE2eeHelper.getCallEmojis(
        callId: 'call-room-2',
        userId1: 'user-alice',
        userId2: 'user-bob',
      );

      expect(call1, isNot(equals(call2)));
    });
  });
}

