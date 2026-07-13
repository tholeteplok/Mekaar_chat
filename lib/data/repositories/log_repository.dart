import '../models/security_log_model.dart';
import '../services/supabase_service.dart';

class LogRepository {
  final SupabaseService _supabaseService;

  LogRepository(this._supabaseService);

  // Fetch security logs (filtering out soft deleted ones)
  Future<List<SecurityLog>> getLogs() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final response = await _supabaseService.client
        .from('security_logs')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    return (response as List).map((e) => SecurityLog.fromJson(e)).toList();
  }

  // Soft-delete a log item
  Future<void> deleteLogItem(String logId) async {
    await _supabaseService.client
        .from('security_logs')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', logId);
  }

  // Clear all logs (soft delete)
  Future<void> clearAllLogs() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    await _supabaseService.client
        .from('security_logs')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
  }

  // Export logs to CSV string
  Future<String> exportLogsToCSV() async {
    final logs = await getLogs();
    
    final StringBuffer buffer = StringBuffer();
    // Headers
    buffer.writeln('ID,Event Type,Details,Created At');
    
    for (final log in logs) {
      final detailsStr = log.details != null ? log.details.toString().replaceAll(',', ';') : '';
      buffer.writeln('${log.id},${log.eventType},"$detailsStr",${log.createdAt.toIso8601String()}');
    }
    
    return buffer.toString();
  }

  // Log custom event
  Future<void> logEvent(String eventType, Map<String, dynamic> details) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    await _supabaseService.client.from('security_logs').insert({
      'user_id': userId,
      'event_type': eventType,
      'details': details,
    });
  }
}
