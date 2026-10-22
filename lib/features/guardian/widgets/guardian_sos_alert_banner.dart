import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../data/services/alarm_service.dart';
import '../../sos/providers/sos_provider.dart';

/// Provider sesi darurat aktif dari orang yang kita jaga
final activeGuardedSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(sosRepositoryProvider);
  return repo.getActiveSessionsForMe();
});

/// GuardianSOSAlertBanner — Banner darurat yang muncul di layar obrolan Guardian
/// saat orang yang mereka jaga sedang dalam Mode SOS aktif.
class GuardianSOSAlertBanner extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const GuardianSOSAlertBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessionsAsync = ref.watch(activeGuardedSessionsProvider);

    return activeSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        final first = sessions.first;
        final sessionId = first['id'] as String? ?? '';
        final victimName = first['user_name'] as String? ?? 'Seseorang';
        final victimId = first['user_id'] as String? ?? '';
        final victimMessage = first['message'] as String?;

        final hasTacticalMessage =
            victimMessage != null && victimMessage.trim().isNotEmpty;

        return Padding(
          padding: padding,
          child: MekaarBanner(
            color: MekaarColors.sosRed,
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            icon: SolarIconsBold.danger,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🚨 DARURAT: $victimName butuh bantuan!',
                  style: MekaarTypography.labelLG.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTacticalMessage
                      ? '💬 "$victimMessage"'
                      : 'Sesi SOS sedang aktif • Ketuk untuk lacak',
                  style: MekaarTypography.bodySM.copyWith(
                    color: hasTacticalMessage
                        ? const Color(0xFFFEF08A) // Soft warning yellow
                        : Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: hasTacticalMessage
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    AlarmService.stopSOSAlarm();
                  },
                  borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    ),
                    child: const Icon(
                      SolarIconsOutline.volumeCross,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.destructive);
                    AlarmService.stopSOSAlarm();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.sosViewer,
                      arguments: {
                        'sessionId': sessionId,
                        'userId': victimId,
                        'userName': victimName,
                        'message': victimMessage,
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          SolarIconsBold.routing,
                          color: MekaarColors.sosRed,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Lacak',
                          style: TextStyle(
                            color: MekaarColors.sosRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
