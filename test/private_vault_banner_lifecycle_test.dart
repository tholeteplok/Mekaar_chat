import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_active_banner.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';

class _FakeContactsNotifier
    extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  _FakeContactsNotifier(List<ContactItem> items)
      : super(AsyncValue.data(items));

  @override
  Future<void> refreshContacts({bool forceLoading = false}) async {}

  @override
  Future<void> updateVaultStatus(
    String contactUserId,
    bool isVaulted, {
    int vaultSlot = 1,
  }) async {
    state = state.whenData((list) => list.map((item) {
          if (item.contactUserId == contactUserId) {
            return item.copyWith(isVaulted: isVaulted, vaultSlot: vaultSlot);
          }
          return item;
        }).toList());
  }

  @override
  Future<void> deleteContact(String contactUserId) async {}
}

class _FakeHiddenContactUserIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenContactUserIdsNotifier {
  _FakeHiddenContactUserIdsNotifier(super.ids);

  @override
  Future<void> loadHiddenContacts() async {}

  @override
  Future<bool> toggleHide(String contactUserId) async {
    final next = Set<String>.from(state);
    final willHide = !next.contains(contactUserId);
    if (willHide) {
      next.add(contactUserId);
    } else {
      next.remove(contactUserId);
    }
    state = next;
    return willHide;
  }

  @override
  Future<void> hideContact(String contactUserId) async {
    state = {...state, contactUserId};
  }

  @override
  Future<void> removeContact(String contactUserId) async {
    final next = Set<String>.from(state)..remove(contactUserId);
    state = next;
  }

  @override
  bool isHidden(String contactUserId) => state.contains(contactUserId);
}

class _FakeHiddenRoomIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenRoomIdsNotifier {
  _FakeHiddenRoomIdsNotifier(super.ids);

  @override
  Future<void> loadHiddenRooms() async {}

  @override
  Future<bool> toggleHide(String roomId) async {
    final next = Set<String>.from(state);
    final willHide = !next.contains(roomId);
    if (willHide) {
      next.add(roomId);
    } else {
      next.remove(roomId);
    }
    state = next;
    return willHide;
  }

  @override
  bool isHidden(String roomId) => state.contains(roomId);
}

class _FakePrivateContactRepository implements PrivateContactRepository {
  @override
  Future<bool> hasPasscode() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now().toUtc();

  final contact1 = ContactItem(
    id: 'c_1',
    contactUserId: 'u_1',
    username: 'user_satu',
    displayName: 'Kontak Rahasia 1',
    createdAt: now,
    isVaulted: true,
    vaultSlot: 1,
  );

  final contact2 = ContactItem(
    id: 'c_2',
    contactUserId: 'u_2',
    username: 'user_dua',
    displayName: 'Kontak Rahasia 2',
    createdAt: now,
    isVaulted: true,
    vaultSlot: 1,
  );

  group('PrivateVaultActiveBanner & Dialogs Lifecycle Tests', () {
    testWidgets(
      'Skenario 1 (Kontak Tunggal): Unhide kontak terakhir langsung menutup vault dan menyembunyikan banner',
      (tester) async {
        late WidgetRef capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privateContactRepositoryProvider
                  .overrideWithValue(_FakePrivateContactRepository()),
              userContactsProvider.overrideWith(
                (ref) => _FakeContactsNotifier([contact1]),
              ),
              hiddenContactUserIdsProvider.overrideWith(
                (ref) => _FakeHiddenContactUserIdsNotifier({'u_1'}),
              ),
              hiddenRoomIdsProvider.overrideWith(
                (ref) => _FakeHiddenRoomIdsNotifier({}),
              ),
              unlockedVaultSlotsProvider.overrideWith((ref) => {1}),
              privateVaultUnlockedProvider.overrideWith((ref) => true),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const Column(
                      children: [
                        PrivateVaultActiveBanner(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Banner wajib tampil karena vault terbuka dan kontak 1 masih ada di vault
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsOneWidget);
        expect(capturedRef.read(privateVaultUnlockedProvider), isTrue);

        // 2. Unhide kontak 1 (swipe kiri "Tampilkan")
        final BuildContext ctx = tester.element(find.byType(Scaffold));
        final isHiddenResult =
            await PrivateVaultDialogs.toggleContactHiddenWithAuth(
          ctx,
          capturedRef,
          contactUserId: 'u_1',
          contactName: 'Kontak Rahasia 1',
        );

        expect(isHiddenResult, isFalse);
        await tester.pumpAndSettle();

        // 3. Verifikasi: sesi vault langsung terkunci seketika
        expect(capturedRef.read(privateVaultUnlockedProvider), isFalse);
        expect(capturedRef.read(unlockedVaultSlotsProvider), isEmpty);

        // 4. Verifikasi: Banner langsung hilang seketika tanpa perlu restart
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsNothing);
      },
    );

    testWidgets(
      'Skenario 2 (Multi Kontak): Unhide 1 kontak dari 2 membuat banner tetap aktif; unhide kontak ke-2 langsung menghilangkan banner',
      (tester) async {
        late WidgetRef capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privateContactRepositoryProvider
                  .overrideWithValue(_FakePrivateContactRepository()),
              userContactsProvider.overrideWith(
                (ref) => _FakeContactsNotifier([contact1, contact2]),
              ),
              hiddenContactUserIdsProvider.overrideWith(
                (ref) => _FakeHiddenContactUserIdsNotifier({'u_1', 'u_2'}),
              ),
              hiddenRoomIdsProvider.overrideWith(
                (ref) => _FakeHiddenRoomIdsNotifier({}),
              ),
              unlockedVaultSlotsProvider.overrideWith((ref) => {1}),
              privateVaultUnlockedProvider.overrideWith((ref) => true),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const Column(
                      children: [
                        PrivateVaultActiveBanner(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Banner wajib tampil
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsOneWidget);
        expect(capturedRef.read(privateVaultUnlockedProvider), isTrue);

        // 2. Unhide kontak 1 saja
        final BuildContext ctx = tester.element(find.byType(Scaffold));
        await PrivateVaultDialogs.toggleContactHiddenWithAuth(
          ctx,
          capturedRef,
          contactUserId: 'u_1',
          contactName: 'Kontak Rahasia 1',
        );
        await tester.pumpAndSettle();

        // 3. Verifikasi: Masih ada kontak 2 di vault -> Banner TETAP aktif dan sesi tetap unlocked
        expect(capturedRef.read(privateVaultUnlockedProvider), isTrue);
        expect(capturedRef.read(unlockedVaultSlotsProvider), contains(1));
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsOneWidget);

        // 4. Unhide kontak 2 (sekarang 0 kontak tersisa)
        await PrivateVaultDialogs.toggleContactHiddenWithAuth(
          ctx,
          capturedRef,
          contactUserId: 'u_2',
          contactName: 'Kontak Rahasia 2',
        );
        await tester.pumpAndSettle();

        // 5. Verifikasi: Sekarang semua kontak vault telah ditampilkan -> Banner langsung hilang dan vault terkunci
        expect(capturedRef.read(privateVaultUnlockedProvider), isFalse);
        expect(capturedRef.read(unlockedVaultSlotsProvider), isEmpty);
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsNothing);
      },
    );

    testWidgets(
      'Skenario 3 (Reaktif Fallback Banner): Banner otomatis hilang jika daftar kontak vaulted kosong meski provider belum di-relock',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            userContactsProvider.overrideWith(
              (ref) => _FakeContactsNotifier([]),
            ),
            hiddenContactUserIdsProvider.overrideWith(
              (ref) => _FakeHiddenContactUserIdsNotifier({}),
            ),
            hiddenRoomIdsProvider.overrideWith(
              (ref) => _FakeHiddenRoomIdsNotifier({}),
            ),
            unlockedVaultSlotsProvider.overrideWith((ref) => {1}),
            // Flag provider sengaja diset true untuk menguji reaktif fallback guard
            privateVaultUnlockedProvider.overrideWith((ref) => true),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: PrivateVaultActiveBanner(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Banner TIDAK boleh tampil karena tidak ada kontak/obrolan vault yang aktif
        expect(find.text('Vault Terbuka (Sesi Aktif)'), findsNothing);
      },
    );
  });
}
