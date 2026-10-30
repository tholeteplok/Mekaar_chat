import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/services/haptic_service.dart';

/// Pill popup floating reaction emoji yang muncul saat pesan dipilih.
///
/// Mendukung animasi "mekar" bertahap (staggered bounce) untuk tiap emoji,
/// pembesaran halus wadah dari arah gelembung pesan, target sentuh minimal 48dp,
/// pelabelan semantik aksesibilitas, dan penghormatan penuh terhadap preferensi reduce-motion.
class ChatFloatingReactionPill extends StatefulWidget {
  final bool isMe;
  final ValueChanged<String> onReact;

  const ChatFloatingReactionPill({
    super.key,
    required this.isMe,
    required this.onReact,
  });

  @override
  State<ChatFloatingReactionPill> createState() =>
      _ChatFloatingReactionPillState();
}

class _ChatFloatingReactionPillState extends State<ChatFloatingReactionPill>
    with SingleTickerProviderStateMixin {
  static const List<String> _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  late final AnimationController _controller;
  late final Animation<double> _containerScale;
  late final Animation<double> _containerFade;
  late final List<Animation<double>> _scales;
  late final List<Animation<double>> _fades;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: MekaarMotion.slow);

    _containerScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: MekaarMotion.standard),
      ),
    );

    _containerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _scales = List.generate(_emojis.length, (i) {
      final start =
          (MekaarMotion.staggerStep.inMilliseconds * i) /
          MekaarMotion.slow.inMilliseconds;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: MekaarMotion.bounce),
      );
    });

    _fades = List.generate(_emojis.length, (i) {
      final start =
          (MekaarMotion.staggerStep.inMilliseconds * i) /
          MekaarMotion.slow.inMilliseconds;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.value = 1.0;
    } else if (!_controller.isAnimating && _controller.value == 0.0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ChatFloatingReactionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (context.reduceMotion) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = widget.isMe
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ScaleTransition(
        scale: _containerScale,
        alignment: alignment,
        child: FadeTransition(
          opacity: _containerFade,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(MekaarRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: MekaarColors.borderOf(context),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_emojis.length, (i) {
                final emoji = _emojis[i];
                return ScaleTransition(
                  scale: _scales[i],
                  child: FadeTransition(
                    opacity: _fades[i],
                    child: Semantics(
                      label: 'Reaksi $emoji',
                      button: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            MekaarRadius.pill,
                          ),
                          onTap: () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            widget.onReact(emoji);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 48,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
