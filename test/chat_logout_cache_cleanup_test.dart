import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<void> signOut() async {}
}

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'user-1';
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repo, User initialUser) {
    state = AuthState(user: initialUser, isLoading: false);
  }
}

void main() {
  test('K1: AuthNotifier.logout() membersihkan seluruh cache plaintext & pool room di ChatRepository', () async {
    const fakeUser = User(
      id: 'user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-11-21T00:00:00Z',
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
        authProvider.overrideWith((ref) {
          final repo = ref.watch(authRepositoryProvider);
          return _TestAuthNotifier(repo, fakeUser);
        }),
      ],
    );
    addTearDown(container.dispose);

    // 1. Ambil instance kanonik chatRepositoryProvider & isi cache sesi in-memory
    final chatRepo = container.read(chatRepositoryProvider);
    final controller = StreamController<List<Message>>.broadcast();
    final sampleMsg = Message(
      id: 'msg-secret-1',
      roomId: 'room-1',
      senderId: 'user-2',
      content: 'Pesan rahasia terdekripsi',
      type: MessageType.text,
      createdAt: DateTime.utc(2026, 11, 21, 10, 0),
      updatedAt: DateTime.utc(2026, 11, 21, 10, 0),
      isEncrypted: true,
    );

    chatRepo.decryptedContentCache['msg-secret-1'] = 'Pesan rahasia terdekripsi';
    chatRepo.activeRoomMessagePools['room-1'] = {'msg-secret-1': sampleMsg};
    chatRepo.activeRoomControllers['room-1'] = controller;

    expect(chatRepo.decryptedContentCache, isNotEmpty);
    expect(chatRepo.activeRoomMessagePools, isNotEmpty);
    expect(chatRepo.activeRoomControllers, isNotEmpty);
    expect(controller.isClosed, isFalse);

    // 2. Jalankan logout melalui AuthNotifier
    await container.read(authProvider.notifier).logout();

    // 3. Verifikasi seluruh cache plaintext, pool pesan, dan controller bersih total
    expect(container.read(authProvider).user, isNull);
    expect(chatRepo.decryptedContentCache, isEmpty);
    expect(chatRepo.activeRoomMessagePools, isEmpty);
    expect(chatRepo.activeRoomControllers, isEmpty);
    expect(controller.isClosed, isTrue);
  });
}
