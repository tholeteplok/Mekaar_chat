import '../services/supabase_service.dart';

class ReportRepository {
  final SupabaseService _supabase;

  ReportRepository(this._supabase);

  /// Mengirimkan laporan penyalahgunaan ke Supabase RPC `submit_user_report`
  Future<String> submitReport({
    required String reportedUserId,
    required String category,
    required String reason,
    String? roomId,
    String? messageId,
    String? evidenceSnapshot,
  }) async {
    final response = await _supabase.client.rpc(
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

    return response as String;
  }
}
