import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/colors.dart';
import '../../features/sos/providers/sos_provider.dart';

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
    final isDark = forceDark || Theme.of(context).brightness == Brightness.dark;
    
    // Listen to SOS active state
    bool isSosActive = false;
    try {
      isSosActive = ref.watch(sosProvider).isSOSActive;
    } catch (_) {}

    LinearGradient gradient;
    if (isSosActive) {
      gradient = MekaarGradients.canvasSos;
    } else if (isDark) {
      gradient = MekaarGradients.canvasDark;
    } else {
      gradient = MekaarGradients.canvasLight;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: child,
    );
  }
}
