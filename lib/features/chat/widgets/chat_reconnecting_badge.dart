import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// Badge tipis non-blocking yang muncul saat stream pesan sedang mencoba
/// menyambung ulang setelah gangguan Realtime sesaat (retry+backoff).
class ReconnectingBadge extends StatelessWidget {
  const ReconnectingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = MekaarColors.surfaceOf(context);
    final accent = MekaarColors.accentOf(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            'Menyambung ulang…',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
