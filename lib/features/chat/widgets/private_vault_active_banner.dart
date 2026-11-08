import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PrivateVaultActiveBanner — Dipertahankan untuk kompatibilitas mundur.
/// Sesuai UX redesign & stealth requirements:
/// Banner 'Vault Terbuka (Sesi Aktif)' ditiadakan untuk mencegah visual leak.
class PrivateVaultActiveBanner extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final String title;

  const PrivateVaultActiveBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    this.title = 'Vault Terbuka (Sesi Aktif)',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
