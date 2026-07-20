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

  /// Ekspor log yang ditandatangani dengan tanda tangan digital Ed25519 via
  /// Edge Function (bukan sekadar hash SHA-256 — lihat komentar di
  /// supabase/functions/sign-logs/index.ts untuk perbedaannya).
  /// Mengembalikan map {'csv', 'signature', 'public_key', 'algorithm',
  /// 'signed_at', 'statement'} jika function tersedia & terkonfigurasi;
  /// jika tidak, fallback ke CSV lokal tanpa tanda tangan.
  Future<Map<String, String>> exportSignedLogs() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'sign-logs',
        body: {'format': 'csv'},
      );
      final data = response.data;
      if (data is Map && data['csv'] != null && data['signature'] != null) {
        return {
          'csv': data['csv'] as String,
          'signature': (data['signature'] as String?) ?? '',
          'public_key': (data['public_key'] as String?) ?? '',
          'algorithm': (data['algorithm'] as String?) ?? '',
          'signed_at': (data['signed_at'] as String?) ?? '',
          'statement': (data['statement'] as String?) ?? '',
        };
      }
    } catch (_) {
      // Edge Function belum di-deploy/dikonfigurasi — fallback ke ekspor lokal.
    }
    final csv = await _logRepository.exportLogsToCSV();
    return {
      'csv': csv,
      'signature': '',
      'public_key': '',
      'algorithm': '',
      'signed_at': '',
      'statement': '',
    };
  }
}

// Global Provider for Security Logs
final securityLogProvider =
    StateNotifierProvider<SecurityLogNotifier, List<SecurityLog>>((ref) {
      final repo = ref.watch(logRepositoryProvider);
      return SecurityLogNotifier(repo);
    });
