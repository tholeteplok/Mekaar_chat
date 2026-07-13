import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/security_log_model.dart';
import '../../../data/repositories/log_repository.dart';
import '../../auth/providers/auth_provider.dart';

// Repository Provider
final logRepositoryProvider = Provider<LogRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return LogRepository(supabaseService);
});

// State Notifier
class SecurityLogNotifier extends StateNotifier<List<SecurityLog>> {
  final LogRepository _logRepository;

  SecurityLogNotifier(this._logRepository) : super([]) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      final list = await _logRepository.getLogs();
      state = list;
    } catch (_) {}
  }

  Future<void> deleteLog(String logId) async {
    await _logRepository.deleteLogItem(logId);
    await loadLogs();
  }

  Future<void> clearLogs() async {
    await _logRepository.clearAllLogs();
    await loadLogs();
  }

  Future<String> exportLogs() async {
    return await _logRepository.exportLogsToCSV();
  }

  Future<void> logEvent(String eventType, Map<String, dynamic> details) async {
    await _logRepository.logEvent(eventType, details);
    await loadLogs();
  }
}

// Global Provider for Security Logs
final securityLogProvider = StateNotifierProvider<SecurityLogNotifier, List<SecurityLog>>((ref) {
  final repo = ref.watch(logRepositoryProvider);
  return SecurityLogNotifier(repo);
});
