import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/theme_resolver.dart';
import '../constants/time_palette.dart';
import '../providers/theme_provider.dart';
import '../providers/time_tick_provider.dart';
import '../../features/sos/providers/sos_provider.dart';

/// Canvas gradient yang dipakai di seluruh app. Gradient ditentukan oleh
/// [ThemeResolver] dari preferensi user + jam device (untuk mode auto).
class MekaarCanvas extends ConsumerWidget {
  final Widget child;
  final bool forceDark;

  const MekaarCanvas({
    super.key,
    required this.child,
    this.forceDark = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger rebuild per menit agar auto-theme bisa switch palet.
    ref.watch(timeTickProvider);

    // SOS active state — override canvas apapun.
    bool isSosActive = false;
    try {
      isSosActive = ref.watch(sosProvider).isSOSActive;
    } catch (_) {}

    // Resolusi palet dari preferensi user + jam device.
    final pref =
        ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.auto;
    final palette = ThemeResolver.resolvePalette(pref);

    // Kalau dipaksa dark (mis. layar SOS / device-lost), pakai palet malam.
    final effectivePalette = forceDark ? TimePalette.night : palette;
    final gradient = ThemeResolver.resolveCanvasGradient(
      effectivePalette,
      sosActive: isSosActive,
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}
