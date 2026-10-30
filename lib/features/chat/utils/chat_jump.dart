import 'package:flutter/widgets.dart';
import '../../../core/constants/motion.dart';

/// Menggulir list hingga item bertanda [itemKey] terlihat di viewport.
/// Mengembalikan false bila item tak pernah terbangun (tidak ada / belum dimuat).
Future<bool> jumpToKeyedItem({
  required BuildContext context,
  required ScrollController controller,
  required GlobalKey itemKey,
  bool startFromBottom = false,
  int maxSteps = 80,
  double alignment = 0.4,
  Duration? duration,
  Curve? curve,
}) async {
  Future<bool> reveal() async {
    final ctx = itemKey.currentContext;
    if (ctx == null) return false;
    final motionDuration = duration ?? context.motion(MekaarMotion.slow);
    await Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: motionDuration,
      curve: curve ?? MekaarMotion.emphasized,
    );
    return true;
  }

  if (!controller.hasClients) return false;
  if (await reveal()) return true;

  if (startFromBottom) {
    controller.jumpTo(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await reveal()) return true;
  }

  final viewport = controller.position.viewportDimension;
  // Overlap 20% agar tidak ada celah buta di mana item terlewati di antara dua lompatan
  final stepSize = viewport > 0 ? viewport * 0.8 : 400.0;
  double lastMaxScroll = -1;

  for (var i = 0; i < maxSteps; i++) {
    if (!context.mounted || !controller.hasClients) return false;
    final pos = controller.position;

    // Jika sudah di ujung dan maxScrollExtent tidak bertambah lagi setelah layout pass
    if (pos.pixels >= pos.maxScrollExtent &&
        pos.maxScrollExtent == lastMaxScroll) {
      break;
    }
    lastMaxScroll = pos.maxScrollExtent;

    final nextPixels = (pos.pixels + stepSize).clamp(0.0, pos.maxScrollExtent);
    controller.jumpTo(nextPixels);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await reveal()) return true;
  }
  return false;
}
