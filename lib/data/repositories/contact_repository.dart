import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../services/local_message_database.dart';
import '../services/supabase_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/chat_provider.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ContactRepository(supabaseService);
});

class ContactRepository {
  final SupabaseService _supabaseService;

  ContactRepository(this._supabaseService);

  /// Mengambil daftar kontak milik pengguna saat ini.
  Future<List<ContactItem>> getContacts() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabaseService.client
          .from('user_contacts_view')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => ContactItem.fromJson(
                item as Map<String, dynamic>,
                isGuardian: item['is_guardian'] as bool? ?? false,
              ))
          .toList();
    } catch (_) {
      // Fallback: Jika view belum termigrasi di database, query langsung dari user_contacts & public_profiles
      try {
        final fallback = await _supabaseService.client
            .from('user_contacts')
            .select('id, contact_user_id, alias_name, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final items = <ContactItem>[];
        for (final row in fallback as List) {
          final contactId = row['contact_user_id'] as String;
          final profile = await _supabaseService.client
              .from('public_profiles')
              .select('id, username, full_name, display_name, avatar_url, bio')
              .eq('id', contactId)
              .maybeSingle();

          if (profile != null) {
            items.add(ContactItem(
              id: row['id'] as String? ?? '',
              contactUserId: contactId,
              username: profile['username'] as String? ?? '',
              fullName: profile['full_name'] as String?,
              displayName: profile['display_name'] as String?,
              avatarUrl: profile['avatar_url'] as String?,
              bio: profile['bio'] as String?,
              aliasName: row['alias_name'] as String?,
              createdAt: row['created_at'] != null
                  ? DateTime.parse(row['created_at'] as String)
                  : DateTime.now(),
            ));
          }
        }
        return items;
      } catch (_) {
        return [];
      }
    }
  }

  /// Menghapus kontak sekaligus membersihkan riwayat percakapan bilateral.
  Future<void> deleteContact(String contactUserId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    // 1. Panggil RPC di database
    try {
      await _supabaseService.client.rpc(
        'delete_contact_and_chat',
        params: {'p_contact_user_id': contactUserId},
      );
    } catch (_) {
      // Fallback manual jika RPC belum diaplikasikan
      await _supabaseService.client
          .from('user_contacts')
          .delete()
          .eq('user_id', userId)
          .eq('contact_user_id', contactUserId);
    }

    // 2. Bersihkan cache lokal jika ada pesan tersimpan
    try {
      final directRoom = await _supabaseService.client
          .from('room_participants')
          .select('room_id')
          .eq('profile_id', contactUserId)
          .maybeSingle();

      if (directRoom != null && directRoom['room_id'] != null) {
        final roomId = directRoom['room_id'] as String;
        unawaited(LocalMessageDatabase.instance.deleteRoomMessages(roomId));
      }
    } catch (_) {}
  }

  /// Menambahkan pengguna lain ke buku kontak
  Future<void> addContact(String contactUserId, {String? aliasName}) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null || userId == contactUserId) return;

    await _supabaseService.client.from('user_contacts').upsert({
      'user_id': userId,
      'contact_user_id': contactUserId,
      if (aliasName != null && aliasName.trim().isNotEmpty)
        'alias_name': aliasName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Provider StateNotifier untuk mengelola daftar kontak
class ContactsNotifier extends StateNotifier<AsyncValue<List<ContactItem>>> {
  final ContactRepository _repo;
  final Ref _ref;

  ContactsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refreshContacts();
  }

  Future<void> refreshContacts({bool forceLoading = false}) async {
    if (forceLoading || !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final items = await _repo.getContacts();
      state = AsyncValue.data(items);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Menghapus kontak dan otomatis merefresh state kontak serta kamar chat
  Future<void> deleteContact(String contactUserId) async {
    await _repo.deleteContact(contactUserId);
    // Refresh daftar kontak
    await refreshContacts(forceLoading: false);
    // Refresh juga chat rooms agar chat yang dibersihkan langsung hilang dari layar pesan
    _ref.invalidate(chatRoomsProvider);
  }
}

final userContactsProvider =
    StateNotifierProvider<ContactsNotifier, AsyncValue<List<ContactItem>>>((ref) {
  final repo = ref.watch(contactRepositoryProvider);
  return ContactsNotifier(repo, ref);
});
