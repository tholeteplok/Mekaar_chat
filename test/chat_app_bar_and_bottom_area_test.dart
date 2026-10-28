import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_app_bar.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_bottom_area.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_selection_app_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatAppBar & ChatBottomArea Modular Tests (Fase 1 Refactoring)', () {
    testWidgets('ChatAppBar merender mode normal dengan nama obrolan & tombol panggilan', (tester) async {
      final lastSeenNotifier = ValueNotifier<DateTime?>(DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatAppBar(
                chatId: 'test-room-1',
                chatName: 'Alisa Mekaar',
                avatarInitial: 'A',
                isGuardian: false,
                isGroup: false,
                otherLastSeenNotifier: lastSeenNotifier,
                isMuted: false,
                isSelectionMode: false,
                totalSelectedCount: 0,
                selectedMessageIds: const {},
                selectedCallIds: const {},
                rawMessages: const [],
                onClearSelection: () {},
                onReplySelectedMessage: () {},
                onEditSelectedMessage: (_) {},
                onCopySelectedMessages: () {},
                onForwardSelectedMessages: () {},
                onDownloadSelectedFiles: (_) {},
                onSaveSelectedToVault: (_) {},
                onDeleteSelectedMessages: (_) {},
                isSearching: false,
                searchQuery: '',
                searchController: TextEditingController(),
                inChatSearchFocusNode: FocusNode(),
                onCloseSearch: () {},
                onSearchChanged: (_) {},
                onClearSearchQuery: () {},
                onAvatarTap: () {},
                onInitiateCall: (_) {},
                onMenuActionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alisa Mekaar'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.videocamera), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.phoneRounded), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.menuDots), findsOneWidget);
    });

    testWidgets('ChatAppBar merender input pencarian saat isSearching aktif', (tester) async {
      final lastSeenNotifier = ValueNotifier<DateTime?>(null);
      final searchController = TextEditingController(text: 'kata kunci');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatAppBar(
                chatId: 'test-room-1',
                chatName: 'Alisa Mekaar',
                avatarInitial: 'A',
                isGuardian: false,
                isGroup: false,
                otherLastSeenNotifier: lastSeenNotifier,
                isMuted: false,
                isSelectionMode: false,
                totalSelectedCount: 0,
                selectedMessageIds: const {},
                selectedCallIds: const {},
                rawMessages: const [],
                onClearSelection: () {},
                onReplySelectedMessage: () {},
                onEditSelectedMessage: (_) {},
                onCopySelectedMessages: () {},
                onForwardSelectedMessages: () {},
                onDownloadSelectedFiles: (_) {},
                onSaveSelectedToVault: (_) {},
                onDeleteSelectedMessages: (_) {},
                isSearching: true,
                searchQuery: 'kata kunci',
                searchController: searchController,
                inChatSearchFocusNode: FocusNode(),
                onCloseSearch: () {},
                onSearchChanged: (_) {},
                onClearSearchQuery: () {},
                onAvatarTap: () {},
                onInitiateCall: (_) {},
                onMenuActionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('in_chat_search_input')), findsOneWidget);
      expect(find.text('kata kunci'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.closeCircle), findsOneWidget);
    });

    testWidgets('ChatAppBar merender ChatSelectionAppBar saat isSelectionMode aktif', (tester) async {
      final lastSeenNotifier = ValueNotifier<DateTime?>(null);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatAppBar(
                chatId: 'test-room-1',
                chatName: 'Alisa Mekaar',
                avatarInitial: 'A',
                isGuardian: false,
                isGroup: false,
                otherLastSeenNotifier: lastSeenNotifier,
                isMuted: false,
                isSelectionMode: true,
                totalSelectedCount: 3,
                selectedMessageIds: const {'msg-1', 'msg-2', 'msg-3'},
                selectedCallIds: const {},
                rawMessages: const [],
                onClearSelection: () {},
                onReplySelectedMessage: () {},
                onEditSelectedMessage: (_) {},
                onCopySelectedMessages: () {},
                onForwardSelectedMessages: () {},
                onDownloadSelectedFiles: (_) {},
                onSaveSelectedToVault: (_) {},
                onDeleteSelectedMessages: (_) {},
                isSearching: false,
                searchQuery: '',
                searchController: TextEditingController(),
                inChatSearchFocusNode: FocusNode(),
                onCloseSearch: () {},
                onSearchChanged: (_) {},
                onClearSearchQuery: () {},
                onAvatarTap: () {},
                onInitiateCall: (_) {},
                onMenuActionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatSelectionAppBar), findsOneWidget);
      expect(find.text('3 dipilih'), findsOneWidget);
    });

    testWidgets('ChatBottomArea merender ChatComposer dengan controller terhubung', (tester) async {
      final textController = TextEditingController(text: 'Pesan draf');
      final composerFocusNode = FocusNode();
      final composerKey = GlobalKey<ChatComposerState>();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBottomArea(
                chatId: 'test-room-1',
                isGroup: false,
                composerKey: composerKey,
                textController: textController,
                composerFocusNode: composerFocusNode,
                onSend: () {},
                onCancelReply: () {},
                onCancelEdit: () {},
                onSendMedia: (file, type, {caption, isViewOnce}) async {},
                onRestoreE2ee: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text('Pesan draf'), findsOneWidget);
    });
  });
}
