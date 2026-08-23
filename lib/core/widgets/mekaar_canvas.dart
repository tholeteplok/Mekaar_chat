import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/colors.dart';
import '../constants/theme_resolver.dart';
import '../constants/time_palette.dart';
import '../providers/theme_provider.dart';
import '../providers/time_tick_provider.dart';
import '../theme/force_dark_scope.dart';
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
    // SOS active state — override canvas apapun.
    bool isSosActive = false;
    try {
      isSosActive = ref.watch(sosProvider).isSOSActive;
    } catch (_) {}

    // SOS aktif juga memaksa palet gelap agar konten tetap terbaca
    // di atas kanvas merah tua.
    final effectiveForceDark = forceDark || isSosActive;

    if (isSosActive) {
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
      sosActive: isSosActive,
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

