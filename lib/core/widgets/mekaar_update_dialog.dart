import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/update_service.dart';
import '../services/haptic_service.dart';
import 'mekaar_snackbar.dart';
import 'mekaar_update_bottom_sheet.dart';

/// Helper terpusat untuk menampilkan proses pengunduhan dan instalasi update
/// menggunakan Bottom Sheet MEKAAR.
Future<void> showInAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  void Function(String url)? onOpenUrl,
}) async {
  HapticService.trigger(MekaarHapticIntent.selection);

  void defaultOpenUrl(String urlString) async {
    final target = urlString.trim().isNotEmpty
        ? urlString.trim()
        : 'https://github.com/tholeteplok/Mekaar_chat/releases';
    try {
      final uri = Uri.parse(target);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallbackLaunched =
            await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      }
    } catch (_) {
      try {
        final uri = Uri.parse(target);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          MekaarSnackbar.error(context, 'Tidak dapat membuka tautan.');
        }
      }
    }
  }

  // Fallback jika non-Android atau link download kosong
  if (!Platform.isAndroid || info.downloadUrl.isEmpty) {
    final handler = onOpenUrl ?? defaultOpenUrl;
    handler(info.downloadUrl.isNotEmpty ? info.downloadUrl : info.htmlUrl);
    return;
  }

  await MekaarUpdateBottomSheet.showProgressSheet(
    context: context,
    info: info,
  );
}
