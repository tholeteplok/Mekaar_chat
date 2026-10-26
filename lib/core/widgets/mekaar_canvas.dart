import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/colors.dart';
import '../constants/theme_resolver.dart';
import '../constants/theme_preference.dart';
import '../providers/theme_provider.dart';
import '../providers/time_tick_provider.dart';
import '../theme/force_dark_scope.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/sos/providers/sos_provider.dart';

/// Canvas background yang dipakai di seluruh app.
/// Menggunakan kanvas flat solid bersih sesuai spesifikasi Core UI.
class MekaarCanvas extends ConsumerWidget {
  final Widget child;
  final bool forceDark;
  final bool flat;

  const MekaarCanvas({
    super.key,
    required this.child,
    this.forceDark = false,
    this.flat = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SOS active state — override canvas apapun, KECUALI bila dalam mode duress (stealth).
    bool isSosActive = false;
    try {
      isSosActive = ref.watch(sosProvider).isSOSActive;
    } catch (_) {}

    final isDuress = ref.watch(authProvider).lastUnlockWasDuress;
    final showSosCanvas = isSosActive && !isDuress;

    // SOS aktif (non-duress) juga memaksa palet gelap agar konten tetap terbaca
    // di atas kanvas merah tua.
    final effectiveForceDark = forceDark || showSosCanvas;

    if (showSosCanvas) {
      return ForceDarkScope(
        forceDark: true,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.sosDeep,
          child: child,
        ),
      );
    }

    if (flat && !effectiveForceDark) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    }

    // Trigger rebuild per menit agar auto-theme bisa switch mode.
    ref.watch(timeTickProvider);

    final pref =
        ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.auto;
    final gradient = ThemeResolver.resolveCanvasGradient(
      pref,
      sosActive: showSosCanvas,
      forceDark: effectiveForceDark,
    );

    return ForceDarkScope(
      forceDark: effectiveForceDark,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: child,
      ),
    );
  }
}
