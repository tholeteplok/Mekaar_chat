import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<String> exportLogs() async {
    return await _logRepository.exportLogsToCSV();
  }

  /// Ekspor log yang ditandatangani kriptografis (SHA-256) via Edge Function.
  /// Mengembalikan map {'csv', 'signature', 'signed_at', 'statement'} jika
  /// function tersedia; jika tidak (belum deploy), fallback ke CSV lokal.
  Future<Map<String, String>> exportSignedLogs() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'sign-logs',
        body: {'format': 'csv'},
      );
      final data = response.data;
      if (data is Map && data['csv'] != null) {
        return {
          'csv': data['csv'] as String,
          'signature': (data['signature'] as String?) ?? '',
          'signed_at': (data['signed_at'] as String?) ?? '',
          'statement': (data['statement'] as String?) ?? '',
        };
      }
    } catch (_) {
      // Edge Function belum di-deploy — fallback ke ekspor lokal.
    }
    final csv = await _logRepository.exportLogsToCSV();
    return {'csv': csv, 'signature': '', 'signed_at': '', 'statement': ''};
  }
}

// Global Provider for Security Logs
final securityLogProvider =
    StateNotifierProvider<SecurityLogNotifier, List<SecurityLog>>((ref) {
      final repo = ref.watch(logRepositoryProvider);
      return SecurityLogNotifier(repo);
    });
