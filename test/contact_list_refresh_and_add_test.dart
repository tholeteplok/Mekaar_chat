import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_elastic_pull_scope.dart';
import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

class FakeContactRepository implements ContactRepository {
  List<ContactItem> contacts = [];
  bool throwOnFetch = false;

  @override
  Future<List<ContactItem>> getContacts() async {
    if (throwOnFetch) throw Exception('Gagal mengambil kontak');
    return List.from(contacts);
  }

  @override
  Future<void> addContact(String contactUserId, {String? aliasName}) async {
    contacts.add(ContactItem(
      id: 'contact_${contacts.length + 1}',
      contactUserId: contactUserId,
      username: 'user_$contactUserId',
      aliasName: aliasName,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteContact(String contactUserId) async {
    contacts.removeWhere((c) => c.contactUserId == contactUserId);
  }

  @override
  Future<void> updateContactVaultStatus(
    String contactUserId,
    bool isVaulted, {
    int vaultSlot = 1,
  }) async {
    final idx = contacts.indexWhere((c) => c.contactUserId == contactUserId);
    if (idx != -1) {
      contacts[idx] = contacts[idx].copyWith(
        isVaulted: isVaulted,
        vaultSlot: vaultSlot,
      );
    }
  }

  @override
  Future<void> deleteVaultSlot(int vaultSlot) async {
    for (var i = 0; i < contacts.length; i++) {
      if (contacts[i].vaultSlot == vaultSlot) {
        contacts[i] = contacts[i].copyWith(isVaulted: false);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  FakeChatRoomsNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<void> reloadFromLocalCache({bool syncRemoteInBackground = true}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUnmountScopeWidget extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onEvent;

  const _TestUnmountScopeWidget({
    required this.onRefresh,
    required this.onEvent,
  });

  @override
  State<_TestUnmountScopeWidget> createState() => _TestUnmountScopeWidgetState();
}

class _TestUnmountScopeWidgetState extends State<_TestUnmountScopeWidget> {
  final searchCtrl = TextEditingController();
  final focusNode = FocusNode();
  bool isSearchActive = false;
  bool isRefreshingState = false;

  @override
  void dispose() {
    searchCtrl.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MekaarTabHeader(
          title: 'Kontak',
          isSearchActive: isSearchActive,
          isSubHeaderSearch: true,
          searchController: searchCtrl,
          searchFocusNode: focusNode,
        ),
        Expanded(
          child: isRefreshingState
              ? const SizedBox(key: ValueKey('unmounted_scope'))
              : MekaarElasticPullScope(
                  isSearchActive: isSearchActive,
                  onSearchActiveChanged: (val) {
                    if (mounted) setState(() => isSearchActive = val);
                  },
                  onRefreshingChanged: (val) {
                    widget.onEvent(val);
                    if (mounted) {
                      setState(() {
                        isRefreshingState = val;
                      });
                    }
                  },
                  searchController: searchCtrl,
                  searchFocusNode: focusNode,
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: 15,
                    itemBuilder: (context, i) => ListTile(
                      title: Text('Contact $i'),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactsNotifier Unit Tests', () {
    test('addContact() menambahkan kontak dan langsung menyegarkan state', () async {
      final fakeRepo = FakeContactRepository();
      final container = ProviderContainer(
        overrides: [
          contactRepositoryProvider.overrideWithValue(fakeRepo),
          chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userContactsProvider.notifier);
      await notifier.refreshContacts(forceLoading: true);

      expect(container.read(userContactsProvider).value, isEmpty);

      // Tambahkan kontak baru
      await notifier.addContact('user_123', aliasName: 'Budi');

      final current = container.read(userContactsProvider).value;
      expect(current, isNotNull);
      expect(current!.length, 1);
      expect(current.first.contactUserId, 'user_123');
      expect(current.first.aliasName, 'Budi');
      expect(current.first.effectiveName, 'Budi');
    });

    test('refreshContacts(forceLoading: false) tidak mereset state ke loading jika sudah ada data', () async {
      final fakeRepo = FakeContactRepository();
      fakeRepo.contacts = [
        ContactItem(
          id: 'c1',
          contactUserId: 'u1',
          username: 'user_1',
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          contactRepositoryProvider.overrideWithValue(fakeRepo),
          chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userContactsProvider.notifier);
      await notifier.refreshContacts(forceLoading: true);

      expect(container.read(userContactsProvider).hasValue, isTrue);
      expect(container.read(userContactsProvider).isLoading, isFalse);

      // Tambahkan data di repo tanpa notif
      fakeRepo.contacts.add(
        ContactItem(
          id: 'c2',
          contactUserId: 'u2',
          username: 'user_2',
          createdAt: DateTime.now(),
        ),
      );

      // Jalankan refreshContacts dengan forceLoading: false
      final refreshFuture = notifier.refreshContacts(forceLoading: false);

      // State harus tetap mempertahankan nilai data lama selama proses
      expect(container.read(userContactsProvider).hasValue, isTrue);

      await refreshFuture;
      expect(container.read(userContactsProvider).value!.length, 2);
    });

    test('deleteContact() menghapus kontak dari list dan state diperbarui', () async {
      final fakeRepo = FakeContactRepository();
      fakeRepo.contacts = [
        ContactItem(
          id: 'c1',
          contactUserId: 'u1',
          username: 'user_1',
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          contactRepositoryProvider.overrideWithValue(fakeRepo),
          chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userContactsProvider.notifier);
      await notifier.refreshContacts(forceLoading: true);
      expect(container.read(userContactsProvider).value!.length, 1);

      await notifier.deleteContact('u1');
      expect(container.read(userContactsProvider).value, isEmpty);
    });
  });

  group('MekaarElasticPullScope Anti-Leak & Unmount Safety Tests', () {
    testWidgets('onRefreshingChanged(false) pasti terpanggil saat dispose meski _isRefreshing aktif', (tester) async {
      final refreshingEvents = <bool>[];
      final refreshCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestUnmountScopeWidget(
              onRefresh: () => refreshCompleter.future,
              onEvent: (val) {
                refreshingEvents.add(val);
              },
            ),
          ),
        ),
      );

      final firstItem = find.text('Contact 0');
      final gesture = await tester.startGesture(tester.getCenter(firstItem));
      // Deep pull melebihi 260px untuk memicu refresh threshold
      await gesture.moveBy(const Offset(0, 260));
      await tester.pump();
      await gesture.up();
      // Pump frame agar scroll physics release terdeteksi dan unmount berjalan
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Verifikasi bahwa refresh sempat dimulai (true), lalu karena unmount langsung direset aman ke false
      expect(refreshingEvents.contains(true), isTrue, reason: 'Harus pernah memicu onRefreshingChanged(true)');
      expect(refreshingEvents.last, isFalse, reason: 'Harus diakhiri dengan onRefreshingChanged(false)');

      refreshCompleter.complete();
    });
  });
}
