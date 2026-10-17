import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/providers/call_state_provider.dart';
import '../../features/sos/providers/sos_provider.dart';
import '../navigation/app_navigator.dart';
import '../providers/update_download_provider.dart';
import 'mekaar_floating_update_pill.dart';
import 'mekaar_update_bottom_sheet.dart';

/// Overlay tingkat aplikasi yang memantau status unduhan pembaruan,
/// menampilkan [MekaarFloatingUpdatePill] saat diminimalkan, dan
/// secara cerdas memicu prompt instalasi saat selesai (menghormati DND saat panggilan/SOS aktif).
class MekaarUpdateOverlay extends ConsumerWidget {
  final Widget child;

  const MekaarUpdateOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pantau perubahan status penyelesaian unduhan
    ref.listen<UpdateDownloadState>(updateDownloadProvider, (prev, next) {
      if (next.isCompleted && (prev == null || !prev.isCompleted)) {
        final isCallActive = ref.read(activeCallIdProvider) != null;
        final isSosActive = ref.read(sosProvider).isSOSActive;

        // Jangan menginterupsi jika sedang dalam panggilan atau keadaan darurat SOS
        if (!isCallActive && !isSosActive && !next.hasAutoPrompted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = AppNavigator.currentContext;
            if (navContext != null && navContext.mounted && next.info != null) {
              ref.read(updateDownloadProvider.notifier).markAutoPrompted();
              MekaarUpdateBottomSheet.showInstallSheet(
                context: navContext,
                info: next.info!,
              );
            }
          });
        }
      }
    });

    final downloadState = ref.watch(updateDownloadProvider);
    final shouldShowPill = downloadState.isMinimized &&
        (downloadState.hasActiveTask ||
            downloadState.status == UpdateDownloadStatus.error);

    return Stack(
      children: [
        child,
        if (shouldShowPill)
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            right: 16,
            child: const MekaarFloatingUpdatePill(),
          ),
      ],
    );
  }
}
