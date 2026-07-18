import '../models/security_log_model.dart';
import '../services/supabase_service.dart';

class LogRepository {
  final SupabaseService _supabaseService;

  LogRepository(this._supabaseService);

  Future<List<SecurityLog>> getLogs() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('security_logs')
        .select()
        .eq('user_id', userId)
        .eq('event_scope', 'sos')
        .not('sos_session_id', 'is', null)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => SecurityLog.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> logSosEvent({
    required String sessionId,
    required String eventType,
    Map<String, dynamic> details = const {},
  }) async {
    await _supabaseService.client.rpc(
      'log_sos_event',
      params: {
        'target_session_id': sessionId,
        'target_event_type': eventType,
        'event_details': details,
      },
    );
  }

  Future<String> exportLogsToCSV() async {
    final logs = await getLogs();
    final buffer = StringBuffer()
      ..writeln('ID,SOS Session ID,Event Type,Details,Created At');
    for (final log in logs) {
      final details = (log.details ?? const <String, dynamic>{})
          .toString()
          .replaceAll(',', ';')
          .replaceAll('"', '""');
      buffer.writeln(
        '${log.id},${log.sosSessionId},${log.eventType},"$details",${log.createdAt.toIso8601String()}',
      );
    }
    return buffer.toString();
  }
}
