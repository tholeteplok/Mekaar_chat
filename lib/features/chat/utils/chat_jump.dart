import 'package:flutter/widgets.dart';
import '../../../core/constants/motion.dart';

/// Menggulir list hingga item bertanda [itemKey] terlihat di viewport.
/// Mengembalikan false bila item tak pernah terbangun (tidak ada / belum dimuat).
Future<bool> jumpToKeyedItem({
  required BuildContext context,
  required ScrollController controller,
  required GlobalKey itemKey,
  bool startFromBottom = false,
  int? targetIndex,
  int? totalItems,
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

  // 1. Cek langsung apakah item sudah ter-render di viewport saat ini
  if (await reveal()) return true;

  // 2. Jika diminta mulai dari bawah (pesan terbaru pada reverse ListView)
  if (startFromBottom) {
    controller.jumpTo(0);
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (await reveal()) return true;
  }

  // 3. Jika index dan totalItems diketahui, lakukan lompatan awal terarah (index-based estimation)
  if (targetIndex != null && totalItems != null && totalItems > 0) {
    final pos = controller.position;
    if (pos.maxScrollExtent > 0) {
      final estimatedOffset = ((targetIndex / totalItems) * pos.maxScrollExtent)
          .clamp(0.0, pos.maxScrollExtent);
      controller.jumpTo(estimatedOffset);
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (await reveal()) return true;
    }
  }

  final viewport = controller.position.viewportDimension;
  final stepSize = viewport > 0 ? viewport * 0.75 : 350.0;
  double lastMaxScroll = -1;

  // 4. Stepping maju (ke arah pesan lebih lama / maxScrollExtent)
  final initialPixels = controller.position.pixels;
  for (var i = 0; i < maxSteps; i++) {
    if (!context.mounted || !controller.hasClients) return false;
    final pos = controller.position;

    if (pos.pixels >= pos.maxScrollExtent &&
        pos.maxScrollExtent == lastMaxScroll) {
      break;
    }
    lastMaxScroll = pos.maxScrollExtent;

    final nextPixels = (pos.pixels + stepSize).clamp(0.0, pos.maxScrollExtent);
    controller.jumpTo(nextPixels);
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (await reveal()) return true;
  }

  // 5. Stepping mundur (ke arah pesan lebih baru / offset 0) jika sebelumnya berada di atas target
  if (initialPixels > 0) {
    controller.jumpTo(initialPixels);
    for (var i = 0; i < maxSteps; i++) {
      if (!context.mounted || !controller.hasClients) return false;
      final pos = controller.position;
      if (pos.pixels <= 0) break;

      final prevPixels = (pos.pixels - stepSize).clamp(
        0.0,
        pos.maxScrollExtent,
      );
      controller.jumpTo(prevPixels);
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      if (await reveal()) return true;
    }
  }

  return false;
}
