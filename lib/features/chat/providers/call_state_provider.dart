import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk melacak ID panggilan yang sedang aktif di perangkat ini.
/// Digunakan oleh CallInvitationListener untuk menolak panggilan masuk baru (busy)
/// jika user sedang aktif dalam panggilan lain.
final activeCallIdProvider = StateProvider<String?>((ref) => null);
