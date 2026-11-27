import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/app.dart';
import 'package:mekaar_chat/data/models/room_participant_preferences.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/forwarding_protection_repository.dart';
import 'package:mekaar_chat/data/repositories/screen_protection_repository.dart';
import 'package:mekaar_chat/data/services/e2ee_service.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/chat/controllers/chat_screen_controller.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

class _ConsolidatedFakeChatRepo extends ChatRepository {
  int privacyCallCount = 0;
  int legacyDisappearingCalls = 0;
  final bool throwUnimplementedOnConsolidated;

  _ConsolidatedFakeChatRepo({this.throwUnimplementedOnConsolidated = false})
    : super(SupabaseService());

  @override
  Future<
    ({
      int disappearingMinutes,
      bool burnOnExit,
      Map<String, dynamic>? scheduledWipe,
    })
  >
  getRoomPrivacySettings(String roomId) async {
    if (throwUnimplementedOnConsolidated) {
      throw UnimplementedError();
    }
    privacyCallCount++;
    return (
      disappearingMinutes: 60,
      burnOnExit: true,
      scheduledWipe: {
        'scheduled_wipe_mode': 'daily',
        'scheduled_wipe_target_at': '2026-11-28T00:00:00Z',
      },
    );
  }

  @override
  Future<int> getRoomDisappearingMinutes(String roomId) async {
    legacyDisappearingCalls++;
    return 30;
  }

  @override
  Future<bool> getRoomBurnOnExit(String roomId) async => false;

  @override
  Future<Map<String, dynamic>?> getRoomScheduledWipe(String roomId) async =>
      null;

  @override
  Future<RoomParticipantPreferences?> getRoomPreferences(String roomId) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wave 3A: Protection Stream Signature Filtering', () {
    test(
      'ScreenProtectionRepository.extractProtectionSignature mengabaikan mutasi last_read_at',
      () {
        final baseRows = [
          {
            'profile_id': 'u-2',
            'screenshot_protection_enabled': true,
            'screenshot_protection_updated_at': '2026-11-27T01:00:00Z',
            'last_read_at': '2026-11-27T01:00:00Z',
          },
          {
            'profile_id': 'u-1',
            'screenshot_protection_enabled': false,
            'screenshot_protection_updated_at': '2026-11-27T00:30:00Z',
            'last_read_at': '2026-11-27T00:30:00Z',
          },
        ];

        final readReceiptUpdatedRows = [
          {
            'profile_id': 'u-1',
            'screenshot_protection_enabled': false,
            'screenshot_protection_updated_at': '2026-11-27T00:30:00Z',
            'last_read_at': '2026-11-27T02:00:00Z',
          },
          {
            'profile_id': 'u-2',
            'screenshot_protection_enabled': true,
            'screenshot_protection_updated_at': '2026-11-27T01:00:00Z',
            'last_read_at': '2026-11-27T02:05:00Z',
          },
        ];

        final toggledRows = [
          {
            'profile_id': 'u-1',
            'screenshot_protection_enabled': true,
            'screenshot_protection_updated_at': '2026-11-27T02:10:00Z',
            'last_read_at': '2026-11-27T02:00:00Z',
          },
          {
            'profile_id': 'u-2',
            'screenshot_protection_enabled': true,
            'screenshot_protection_updated_at': '2026-11-27T01:00:00Z',
            'last_read_at': '2026-11-27T02:05:00Z',
          },
        ];

        expect(
          ScreenProtectionRepository.extractProtectionSignature(baseRows),
          equals(
            ScreenProtectionRepository.extractProtectionSignature(
              readReceiptUpdatedRows,
            ),
          ),
        );
        expect(
          ScreenProtectionRepository.extractProtectionSignature(baseRows),
          isNot(
            equals(
              ScreenProtectionRepository.extractProtectionSignature(toggledRows),
            ),
          ),
        );
      },
    );

    test(
      'ForwardingProtectionRepository.extractProtectionSignature mengabaikan mutasi last_read_at',
      () {
        final baseRows = [
          {
            'profile_id': 'u-1',
            'forwarding_protection_enabled': true,
            'forwarding_protection_updated_at': '2026-11-27T01:00:00Z',
            'last_read_at': '2026-11-27T01:00:00Z',
          },
        ];
        final readReceiptRows = [
          {
            'profile_id': 'u-1',
            'forwarding_protection_enabled': true,
            'forwarding_protection_updated_at': '2026-11-27T01:00:00Z',
            'last_read_at': '2026-11-27T03:00:00Z',
          },
        ];
        final toggledRows = [
          {
            'profile_id': 'u-1',
            'forwarding_protection_enabled': false,
            'forwarding_protection_updated_at': '2026-11-27T03:05:00Z',
            'last_read_at': '2026-11-27T03:00:00Z',
          },
        ];

        expect(
          ForwardingProtectionRepository.extractProtectionSignature(baseRows),
          equals(
            ForwardingProtectionRepository.extractProtectionSignature(
              readReceiptRows,
            ),
          ),
        );
        expect(
          ForwardingProtectionRepository.extractProtectionSignature(baseRows),
          isNot(
            equals(
              ForwardingProtectionRepository.extractProtectionSignature(
                toggledRows,
              ),
            ),
          ),
        );
      },
    );
  });

  group('Wave 3A: Consolidated loadRoomSettings', () {
    testWidgets(
      'loadRoomSettings memanggil getRoomPrivacySettings (1 query) dan fallback aman saat UnimplementedError',
      (tester) async {
        final consolidatedRepo = _ConsolidatedFakeChatRepo();
        final focusNode = FocusNode();
        final lastSeen = ValueNotifier<DateTime?>(null);
        late ChatScreenController controller;
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
          lastSeen.dispose();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(consolidatedRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  controller = ChatScreenController(
                    chatId: 'room-wave3',
                    ref: ref,
                    composerFocusNode: focusNode,
                    isKeyboardVisible: () => false,
                    isMounted: () => true,
                    otherLastSeenNotifier: lastSeen,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        await controller.loadRoomSettings();
        expect(consolidatedRepo.privacyCallCount, equals(1));
        expect(consolidatedRepo.legacyDisappearingCalls, equals(0));
        expect(controller.autoDeleteMinutes, equals(60));
        expect(controller.burnOnExit, isTrue);
        expect(controller.scheduledWipeMode, equals('daily'));

        // Uji fallback saat UnimplementedError (Fake repo test lama)
        final legacyFakeRepo = _ConsolidatedFakeChatRepo(
          throwUnimplementedOnConsolidated: true,
        );
        final focusNode2 = FocusNode();
        final lastSeen2 = ValueNotifier<DateTime?>(null);
        late ChatScreenController legacyController;
        addTearDown(() {
          legacyController.dispose();
          focusNode2.dispose();
          lastSeen2.dispose();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(legacyFakeRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  legacyController = ChatScreenController(
                    chatId: 'room-wave3-legacy',
                    ref: ref,
                    composerFocusNode: focusNode2,
                    isKeyboardVisible: () => false,
                    isMounted: () => true,
                    otherLastSeenNotifier: lastSeen2,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        await legacyController.loadRoomSettings();
        expect(legacyFakeRepo.legacyDisappearingCalls, equals(1));
        expect(legacyController.autoDeleteMinutes, equals(30));
      },
    );
  });

  group('Wave 3B & 3C: E2eeService clearSession & MekaarApp Stream Stability', () {
    test('E2eeService.clearSession berjalan bersih tanpa error', () {
      E2eeService.instance.clearSession();
      expect(E2eeService.instance.myPublicKeyB64, isNull);
    });

    testWidgets('MekaarApp mounts dan merender MaterialApp tanpa error stream', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MekaarApp()));
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
