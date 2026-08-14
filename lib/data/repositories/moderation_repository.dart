import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Repository untuk fitur Moderasi Admin & Laporan Pengguna (Migration 54).
class ModerationRepository {
  final SupabaseService _supabaseService;
  final Logger _log = Logger();

  ModerationRepository(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Pengajuan Laporan Pengguna (User Report) via RPC `submit_user_report`
  Future<String> submitUserReport({
    required String reportedUserId,
    required String category,
    required String reason,
    String? roomId,
    String? messageId,
    String? evidenceSnapshot,
  }) async {
    try {
      final response = await _client.rpc(
        'submit_user_report',
        params: {
          'p_reported_user_id': reportedUserId,
          'p_category': category,
          'p_reason': reason,
          'p_room_id': roomId,
          'p_message_id': messageId,
          'p_evidence_snapshot': evidenceSnapshot,
        },
      );
      _log.i('ModerationRepository: report submitted successfully ID: $response');
      return response.toString();
    } catch (e) {
      _log.e('ModerationRepository: submitUserReport failed: $e');
      rethrow;
    }
  }

  /// Memeriksa status pembekuan akun (suspension) pengguna saat ini
  Future<Map<String, dynamic>?> fetchSuspensionStatus(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('is_suspended, suspended_at, suspension_reason, legal_hold_active')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      _log.w('ModerationRepository: fetchSuspensionStatus failed: $e');
      return null;
    }
  }

  /// Stream status suspensi pengguna secara real-time
  Stream<Map<String, dynamic>> streamSuspensionStatus(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((records) => records.isNotEmpty ? records.first : {});
  }
}

/// Provider Riverpod untuk ModerationRepository
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ModerationRepository(supabaseService);
});
