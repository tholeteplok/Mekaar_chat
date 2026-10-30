import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/motion.dart';

/// Komponen animasi reaksi emoji yang muncul saat tap/update
class PopReaction extends StatefulWidget {
  final String emoji;
  final int count;
  final VoidCallback? onTap;

  const PopReaction({
    super.key,
    required this.emoji,
    required this.count,
    this.onTap,
  });

  @override
  State<PopReaction> createState() => _PopReactionState();
}

class _PopReactionState extends State<PopReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: MekaarMotion.pop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _ctrl.value = 1.0;
    } else if (!_ctrl.isAnimating && _ctrl.value == 0.0) {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PopReaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      if (context.reduceMotion) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: MekaarMotion.bounce);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MekaarColors.surface2Of(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MekaarColors.borderLight),
      ),
      child: Text(
        '${widget.emoji} ${widget.count}',
        style: const TextStyle(fontSize: 12),
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: context.reduceMotion
          ? badge
          : ScaleTransition(
              scale: Tween<double>(begin: 0.4, end: 1).animate(curved),
              child: badge,
            ),
    );
  }
}

/// Strip daftar reaksi emoji di bawah bubble chat
class ReactionsStrip extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMe;
  final Function(String emoji)? onReact;

  const ReactionsStrip({
    super.key,
    required this.reactions,
    required this.isMe,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 20,
        right: isMe ? 20 : 0,
        bottom: 4,
      ),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return PopReaction(
            emoji: emoji,
            count: count,
            onTap: () => onReact?.call(emoji),
          );
        }).toList(),
      ),
    );
  }
}
