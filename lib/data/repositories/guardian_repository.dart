import '../models/guardian_model.dart';
import '../services/supabase_service.dart';

class GuardianRepository {
  final SupabaseService _supabaseService;

  GuardianRepository(this._supabaseService);

  // Search profile by email or username
  Future<Map<String, dynamic>?> searchProfile(String query) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .or('username.eq."$query",email.eq."$query"')
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Invite a guardian
  Future<Guardian> addGuardian(String guardianUsernameOrEmail, Map<String, bool> permissions) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final profile = await searchProfile(guardianUsernameOrEmail);
    if (profile == null) throw Exception('Pengguna tidak ditemukan');

    final guardianId = profile['id'] as String;
    if (guardianId == userId) throw Exception('Anda tidak bisa menjadikan diri sendiri sebagai guardian');

    final data = {
      'owner_id': userId,
      'guardian_id': guardianId,
      'permissions': permissions,
      'status': 'pending',
      'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    };

    final response = await _supabaseService.client
        .from('guardians')
        .insert(data)
        .select('*, profiles:guardian_id(username, full_name, email)')
        .single();

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
    await _supabaseService.client
        .from('guardians')
        .update({
          'status': 'active',
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        })
        .eq('id', guardianRelationId);
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
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(), // extend 30 days upon update
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
      // Create a reverse relationship with pending status
      await _supabaseService.client.from('guardians').insert({
        'owner_id': currentGuardianId,
        'guardian_id': currentOwnerId,
        'status': 'pending',
        'permissions': record['permissions'],
        'storage_option': record['storage_option'],
      });
    } else {
      // Just activate the reverse record if it is pending
      await _supabaseService.client.from('guardians').update({
        'status': 'active',
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }).eq('id', reverseRecord['id']);
    }
  }
}
