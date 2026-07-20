import '../models/guardian_model.dart';
import 'chat_repository.dart';
import '../services/supabase_service.dart';

class GuardianRepository {
  final SupabaseService _supabaseService;
  final ChatRepository _chatRepository;

  GuardianRepository(this._supabaseService)
    : _chatRepository = ChatRepository(_supabaseService);

  // Search profile by username through a limited public RPC.
  Future<Map<String, dynamic>?> searchProfile(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return null;

    try {
      final response = await _supabaseService.client.rpc(
        'search_public_profiles',
        params: {'search_query': cleanQuery},
      );
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  // Ambil profil publik lawan bicara dan gabungkan ke baris relasi,
  // agar nama tampil tanpa mengekspos email lewat join profiles.
  Future<List<Guardian>> _mergeCounterpartyProfiles(
    List<dynamic> rows,
    String counterpartyKey,
  ) async {
    if (rows.isEmpty) return [];

    final ids = <String>{
      for (final r in rows) (r as Map)[counterpartyKey] as String,
    };

    final profiles = await _supabaseService.client
        .from('public_profiles')
        .select('id, username, full_name')
        .inFilter('id', ids.toList());

    final byId = <String, Map<String, dynamic>>{
      for (final p in profiles as List)
        (p as Map)['id'] as String: Map<String, dynamic>.from(p),
    };

    return rows.map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      row['profiles'] = byId[row[counterpartyKey]];
      return Guardian.fromJson(row);
    }).toList();
  }

  // Invite a guardian lewat RPC server-side (validasi blokir + consent di DB).
  Future<Guardian> addGuardian(
    String guardianUsername,
    Map<String, bool> permissions,
  ) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final profile = await searchProfile(guardianUsername);
    if (profile == null) throw Exception('Pengguna tidak ditemukan');

    final guardianId = profile['id'] as String;
    if (guardianId == userId) {
      throw Exception(
        'Anda tidak bisa menjadikan diri sendiri sebagai guardian',
      );
    }

    final relationId = await _supabaseService.client.rpc(
      'invite_guardian',
      params: {
        'p_owner': userId,
        'p_guardian': guardianId,
        'p_permissions': permissions,
      },
    );

    final response = await _supabaseService.client
        .from('guardians')
        .select()
        .eq('id', relationId as String)
        .single();

    final merged = await _mergeCounterpartyProfiles([response], 'guardian_id');
    return merged.first;
  }

  // Fetch list of guardians I have added
  Future<List<Guardian>> getMyGuardians() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('guardians')
        .select()
        .eq('owner_id', userId);

    return _mergeCounterpartyProfiles(response as List, 'guardian_id');
  }

  // Fetch list of users who have added me as their guardian
  Future<List<Guardian>> getWhoAddedMe() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('guardians')
        .select()
        .eq('guardian_id', userId);

    return _mergeCounterpartyProfiles(response as List, 'owner_id');
  }

  // Accept a guardian invitation lewat RPC (guardian-side, hanya status).
  Future<void> acceptInvitation(String guardianRelationId) async {
    await _supabaseService.client.rpc(
      'accept_guardian_invite',
      params: {'p_relation_id': guardianRelationId},
    );

    final response = await _supabaseService.client
        .from('guardians')
        .select('owner_id')
        .eq('id', guardianRelationId)
        .single();

    final ownerId = response['owner_id'] as String;

    try {
      await _chatRepository.createRoom(ownerId, 'guardian');
    } catch (_) {}
  }

  // Reject/Delete a guardian relation
  Future<void> deleteGuardian(String guardianRelationId) async {
    await _supabaseService.client
        .from('guardians')
        .delete()
        .eq('id', guardianRelationId);
  }

  // Update permissions & storage options
  Future<void> updatePermissions(
    String guardianRelationId, {
    required Map<String, bool> permissions,
    required String storageOption,
  }) async {
    await _supabaseService.client
        .from('guardians')
        .update({
          'permissions': permissions,
          'storage_option': storageOption,
          'expires_at': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(), // extend 30 days upon update
        })
        .eq('id', guardianRelationId);
  }

  // Switch roles (two-way swap request)
  Future<void> initiateSwap(String guardianRelationId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Get current guardian record
    final record = await _supabaseService.client
        .from('guardians')
        .select()
        .eq('id', guardianRelationId)
        .single();

    final currentOwnerId = record['owner_id'] as String;
    final currentGuardianId = record['guardian_id'] as String;

    // Check if swap already exists in reverse direction
    final reverseRecord = await _supabaseService.client
        .from('guardians')
        .select()
        .eq('owner_id', currentGuardianId)
        .eq('guardian_id', currentOwnerId)
        .maybeSingle();

    if (reverseRecord == null) {
      // Buat relasi terbalik lewat RPC; pihak lain harus menyetujui.
      await _supabaseService.client.rpc(
        'invite_guardian',
        params: {
          'p_owner': currentGuardianId,
          'p_guardian': currentOwnerId,
          'p_permissions': record['permissions'],
        },
      );
    }
    // Jika reverseRecord sudah ada dan masih pending, biarkan menunggu persetujuan pihak lain.
  }

  // ── QR invite ──────────────────────────────────────────────

  // Token undangan QR milik sendiri (buat baru jika belum ada).
  Future<String> getMyInviteToken() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .select('invite_token')
        .eq('id', userId)
        .maybeSingle();

    final token = response?['invite_token'] as String?;
    if (token != null && token.isNotEmpty) return token;

    return rotateInviteToken();
  }

  // Ganti token — QR lama langsung tidak berlaku.
  Future<String> rotateInviteToken() async {
    final response = await _supabaseService.client.rpc('rotate_invite_token');
    return response as String;
  }

  // Preview profil pemilik QR sebelum mengirim undangan.
  Future<Map<String, dynamic>?> previewInviteToken(String token) async {
    final response = await _supabaseService.client.rpc(
      'preview_invite_token',
      params: {'p_token': token},
    );
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  // Kirim undangan guardian ke pemilik QR (relasi pending).
  Future<void> redeemInviteToken(
    String token,
    Map<String, bool> permissions,
  ) async {
    await _supabaseService.client.rpc(
      'redeem_invite_token',
      params: {'p_token': token, 'p_permissions': permissions},
    );
  }

  // Panic Unlink / Break Guardian: putuskan hubungan secara instan,
  // catat ke log, dan blokir undangan balik dari guardian tsb selama 24 jam.
  Future<void> breakGuardian(String guardianRelationId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final blockedUntil = DateTime.now()
        .add(const Duration(hours: 24))
        .toIso8601String();

    await _supabaseService.client
        .from('guardians')
        .update({
          'status': 'broken',
          'broken_by_owner': true,
          'blocked_until': blockedUntil,
        })
        .eq('id', guardianRelationId);
  }
}
