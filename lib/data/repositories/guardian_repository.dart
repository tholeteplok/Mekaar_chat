import '../models/guardian_model.dart';
import 'chat_repository.dart';
import 'log_repository.dart';
import '../services/supabase_service.dart';

class GuardianRepository {
  final SupabaseService _supabaseService;
  final ChatRepository _chatRepository;
  final LogRepository _logRepository;

  GuardianRepository(this._supabaseService)
    : _chatRepository = ChatRepository(_supabaseService),
      _logRepository = LogRepository(_supabaseService);

  // Search profile by email or username through a limited public RPC.
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
      // Fallback keeps local MVP usable before 05_security_hardening.sql is applied.
    }

    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('id, username, full_name, email, avatar_url')
          .or('username.eq.$cleanQuery,email.eq.$cleanQuery')
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  // Invite a guardian
  Future<Guardian> addGuardian(
    String guardianUsernameOrEmail,
    Map<String, bool> permissions,
  ) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final profile = await searchProfile(guardianUsernameOrEmail);
    if (profile == null) throw Exception('Pengguna tidak ditemukan');

    final guardianId = profile['id'] as String;
    if (guardianId == userId) {
      throw Exception(
        'Anda tidak bisa menjadikan diri sendiri sebagai guardian',
      );
    }

    final data = {
      'owner_id': userId,
      'guardian_id': guardianId,
      'permissions': permissions,
      'status': 'pending',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
    };

    final response = await _supabaseService.client
        .from('guardians')
        .insert(data)
        .select('*, profiles:guardian_id(username, full_name, email)')
        .single();

    try {
      await _logRepository.logEvent('guardian_invited', {
        'owner_id': userId,
        'guardian_id': guardianId,
        'permissions': permissions,
        'storage_option': data['storage_option'],
      });
    } catch (_) {}

    return Guardian.fromJson(response);
  }

  // Fetch list of guardians I have added
  Future<List<Guardian>> getMyGuardians() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('guardians')
        .select('*, profiles:guardian_id(username, full_name, email)')
        .eq('owner_id', userId);

    return (response as List).map((e) => Guardian.fromJson(e)).toList();
  }

  // Fetch list of users who have added me as their guardian
  Future<List<Guardian>> getWhoAddedMe() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('guardians')
        .select('*, profiles:owner_id(username, full_name, email)')
        .eq('guardian_id', userId);

    return (response as List).map((e) => Guardian.fromJson(e)).toList();
  }

  // Accept a guardian invitation
  Future<void> acceptInvitation(String guardianRelationId) async {
    final response = await _supabaseService.client
        .from('guardians')
        .update({
          'status': 'active',
          'expires_at': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        })
        .eq('id', guardianRelationId)
        .select('*, profiles:guardian_id(username, full_name, email)')
        .single();

    final ownerId = response['owner_id'] as String;
    final guardianId = response['guardian_id'] as String;

    try {
      await _chatRepository.createRoom(guardianId, 'guardian');
    } catch (_) {}

    try {
      String? name;
      if (response['profiles'] != null) {
        final profile = response['profiles'] as Map<String, dynamic>;
        name =
            profile['full_name'] as String? ?? profile['username'] as String?;
      }
      await _logRepository.logEvent('guardian_accepted', {
        'guardian_id': guardianId,
        'owner_id': ownerId,
        'name': name,
      });
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

    try {
      await _logRepository.logEvent('guardian_permissions_updated', {
        'guardian_relation_id': guardianRelationId,
        'permissions': permissions,
        'storage_option': storageOption,
      });
    } catch (_) {}
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
      // Buat relasi terbalik dengan status pending; pihak lain harus menyetujui.
      await _supabaseService.client.from('guardians').insert({
        'owner_id': currentGuardianId,
        'guardian_id': currentOwnerId,
        'status': 'pending',
        'permissions': record['permissions'],
        'storage_option': record['storage_option'],
      });
    }
    // Jika reverseRecord sudah ada dan masih pending, biarkan menunggu persetujuan pihak lain.
  }

  // Panic Unlink / Break Guardian: putuskan hubungan secara instan,
  // catat ke log, dan blokir undangan balik dari guardian tsb selama 24 jam.
  Future<void> breakGuardian(String guardianRelationId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final record = await _supabaseService.client
        .from('guardians')
        .select('owner_id, guardian_id')
        .eq('id', guardianRelationId)
        .single();

    final guardianId = record['guardian_id'] as String;
    final blockedUntil =
        DateTime.now().add(const Duration(hours: 24)).toIso8601String();

    await _supabaseService.client.from('guardians').update({
      'status': 'broken',
      'broken_by_owner': true,
      'blocked_until': blockedUntil,
    }).eq('id', guardianRelationId);

    try {
      await _logRepository.logEvent('guardian_broken', {
        'guardian_relation_id': guardianRelationId,
        'guardian_id': guardianId,
        'blocked_until': blockedUntil,
        'reason': 'panic_unlink',
      });
    } catch (_) {}
  }

  // Cek apakah sebuah guardian (guardian_id) sedang diblokir (cooldown 24j).
  Future<bool> isGuardianBlocked(String guardianId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return false;
    try {
      final response = await _supabaseService.client
          .from('guardians')
          .select('blocked_until')
          .eq('owner_id', userId)
          .eq('guardian_id', guardianId)
          .not('blocked_until', 'is', null)
          .maybeSingle();
      if (response == null) return false;
      final until = DateTime.parse(response['blocked_until'] as String);
      return until.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
