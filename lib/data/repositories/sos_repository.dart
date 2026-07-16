import '../models/sos_session_model.dart';
import '../services/supabase_service.dart';

class SOSRepository {
  final SupabaseService _supabaseService;

  SOSRepository(this._supabaseService);

  // Activate SOS
  Future<SOSSession> startSOS({
    bool gps = true,
    bool mic = false,
    bool video = false,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User belum masuk');

    final response = await _supabaseService.client
        .from('sos_sessions')
        .insert({
          'user_id': userId,
          'status': 'active',
          'gps_enabled': gps,
          'audio_enabled': mic,
          'video_enabled': video,
        })
        .select()
        .single();

    return SOSSession.fromJson(response);
  }

  // End SOS Session
  Future<void> endSession(String sessionId, {String reason = 'manual'}) async {
    await _supabaseService.client
        .from('sos_sessions')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
          'end_reason': reason,
        })
        .eq('id', sessionId);
  }

  // Fetch my active SOS session
  Future<SOSSession?> getMyActiveSOS() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;

    final response = await _supabaseService.client
        .from('sos_sessions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    if (response == null) return null;
    return SOSSession.fromJson(response);
  }

  // Ping location
  Future<void> pingLocation(
    String sessionId,
    double latitude,
    double longitude, {
    double? accuracy,
  }) async {
    await _supabaseService.client.from('location_pings').insert({
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    });
  }

  // Get active SOS sessions from owners who added me as guardian
  Future<List<Map<String, dynamic>>> getActiveSessionsForMe() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    // 1. Fetch userIds where I am the guardian (status active)
    final guardiansResponse = await _supabaseService.client
        .from('guardians')
        .select('owner_id')
        .eq('guardian_id', userId)
        .eq('status', 'active');

    final List<String> ownerIds = (guardiansResponse as List)
        .map((e) => e['owner_id'] as String)
        .toList();

    if (ownerIds.isEmpty) return [];

    // 2. Fetch active SOS sessions of those owners
    final sessionsResponse = await _supabaseService.client
        .from('sos_sessions')
        .select('*, profiles:user_id(username, full_name, email, avatar_url)')
        .inFilter('user_id', ownerIds)
        .eq('status', 'active');

    return (sessionsResponse as List).map((e) {
      final sessionMap = Map<String, dynamic>.from(e);
      final profile = sessionMap['profiles'] as Map<String, dynamic>;
      sessionMap['user_name'] =
          profile['full_name'] as String? ??
          profile['username'] as String? ??
          'User';
      sessionMap['user_email'] = profile['email'] as String? ?? '';
      return sessionMap;
    }).toList();
  }

  Future<Map<String, dynamic>?> getLatestLocationPing(String sessionId) async {
    try {
      final response = await _supabaseService.client
          .from('location_pings')
          .select('latitude, longitude, created_at, accuracy')
          .eq('session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return {
        'latitude': (response['latitude'] as num).toDouble(),
        'longitude': (response['longitude'] as num).toDouble(),
        'timestamp': response['created_at'] as String,
        'accuracy': response['accuracy'] == null
            ? null
            : (response['accuracy'] as num).toDouble(),
      };
    } catch (_) {
      return null;
    }
  }

  // Get active guardian IDs for the current user (owners' guardians)
  Future<List<String>> getMyActiveGuardians() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabaseService.client
          .from('guardians')
          .select('guardian_id')
          .eq('owner_id', userId)
          .eq('status', 'active');

      return (response as List)
          .map((e) => e['guardian_id'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOwnActiveSessionWithPing() async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return null;

      final sessionResponse = await _supabaseService.client
          .from('sos_sessions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (sessionResponse == null) return null;

      final sessionId = sessionResponse['id'] as String;
      final ping = await getLatestLocationPing(sessionId);

      return {'session': sessionResponse, 'ping': ping};
    } catch (_) {
      return null;
    }
  }
}
