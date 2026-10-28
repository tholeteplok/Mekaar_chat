import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/bubbles/bubble_media_helper.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/file_export_service.dart';
import '../../../data/services/local_vault_database.dart';
import '../providers/vault_provider.dart';

/// Handler terisolasi untuk aksi berkas: dekripsi media, ekspor ke folder unduhan
/// publik Mekaar, dan penyimpanan aman ke Brankas Berkas.
class ChatFileActionHandler {
  const ChatFileActionHandler._();

  /// Menyimpan satu pesan media ke Brankas Berkas.
  static Future<void> saveToVault(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required Message message,
    required bool isGroup,
    required Map<String, String> participantNames,
    required String effectiveChatName,
  }) async {
    final mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      MekaarSnackbar.error(context, 'Tidak ada berkas yang dapat disimpan.');
      return;
    }

    MekaarSnackbar.info(context, 'Menyimpan berkas ke Brankas...');

    try {
      final payload = parseMediaPayload(message);
      final file = await getOrDecryptMedia(
        messageId: message.id,
        url: mediaUrl,
        isEncrypted: message.isEncrypted,
        fileKeyB64:
            payload.fileKeyB64.isNotEmpty ? payload.fileKeyB64 : message.content,
      );

      if (file == null || !await file.exists()) {
        if (!context.mounted) return;
        MekaarSnackbar.error(context, 'Gagal memproses berkas media.');
        return;
      }

      if (!context.mounted) return;
      if (!LocalVaultDatabase.instance.isUnlocked) {
        final verified = await MekaarPinVerificationSheet.verify(
          context,
          title: 'Buka Brankas Berkas',
          subtitle: 'Masukkan PIN untuk menyimpan berkas ke Brankas Berkas',
        );
        if (!verified || !context.mounted) return;
      }

      final senderName = isGroup
          ? (participantNames[message.senderId] ?? effectiveChatName)
          : effectiveChatName;

      await ref.read(vaultRepositoryProvider).saveMediaToVault(
            sourceFile: file,
            originalMessageId: message.id,
            customFileName: null,
            senderName: senderName,
            senderId: message.senderId,
            roomId: roomId,
          );

      if (!context.mounted) return;
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        'Berkas berhasil disimpan ke Brankas Berkas',
      );
    } catch (e) {
      if (!context.mounted) return;
      MekaarSnackbar.error(
        context,
        'Gagal menyimpan ke Brankas: $e',
      );
    }
  }

  /// Mengunduh dan mendekripsi daftar berkas terpilih lalu menyimpannya ke Download/Mekaar/.
  static Future<void> downloadSelectedFiles(
    BuildContext context, {
    required List<Message> downloadableMessages,
    required VoidCallback onCompleted,
  }) async {
    onCompleted();
    if (downloadableMessages.isEmpty) return;

    MekaarSnackbar.info(
      context,
      downloadableMessages.length == 1
          ? 'Mengunduh dan mendekripsi berkas...'
          : 'Mengunduh dan mendekripsi ${downloadableMessages.length} berkas...',
    );

    int successCount = 0;
    String? lastExportedPath;

    for (final msg in downloadableMessages) {
      try {
        final localFile = await FileExportService.resolveOrDownloadFile(msg);
        if (localFile != null) {
          final meta = msg.fileMeta;
          final fileName = meta?.fileName ??
              localFile.path.split(Platform.pathSeparator).last;
          final exported = await FileExportService.exportToMekaarDownloads(
            file: localFile,
            fileName: fileName,
            mimeType: meta?.mimeType,
          );
          if (exported != null) {
            successCount++;
            lastExportedPath = exported;
          }
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    if (successCount > 0) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        successCount == 1
            ? 'Berkas berhasil disimpan di $lastExportedPath'
            : '$successCount berkas berhasil disimpan di folder Download/Mekaar/',
      );
    } else {
      HapticService.trigger(MekaarHapticIntent.warning);
      MekaarSnackbar.error(
        context,
        'Gagal mengunduh berkas. Pastikan koneksi internet stabil.',
      );
    }
  }

  /// Menyimpan sekumpulan berkas terpilih ke Brankas Berkas.
  static Future<void> saveSelectedToVault(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required List<Message> savableMessages,
    required bool isGroup,
    required Map<String, String> participantNames,
    required String effectiveChatName,
    required VoidCallback onCompleted,
  }) async {
    if (savableMessages.isEmpty) return;

    if (!LocalVaultDatabase.instance.isUnlocked) {
      final verified = await MekaarPinVerificationSheet.verify(
        context,
        title: 'Buka Brankas Berkas',
        subtitle: 'Masukkan PIN untuk menyimpan berkas ke Brankas Berkas',
      );
      if (!verified || !context.mounted) return;
    }

    if (!context.mounted) return;
    MekaarSnackbar.info(
      context,
      savableMessages.length == 1
          ? 'Menyimpan berkas ke Brankas...'
          : 'Menyimpan ${savableMessages.length} berkas ke Brankas...',
    );

    int savedCount = 0;
    final vaultRepo = ref.read(vaultRepositoryProvider);

    for (final msg in savableMessages) {
      final mediaUrl = msg.mediaUrl;
      if (mediaUrl == null || mediaUrl.isEmpty) continue;

      try {
        final payload = parseMediaPayload(msg);
        final file = await getOrDecryptMedia(
          messageId: msg.id,
          url: mediaUrl,
          isEncrypted: msg.isEncrypted,
          fileKeyB64:
              payload.fileKeyB64.isNotEmpty ? payload.fileKeyB64 : msg.content,
        );

        if (file != null && await file.exists()) {
          final senderName = isGroup
              ? (participantNames[msg.senderId] ?? effectiveChatName)
              : effectiveChatName;

          await vaultRepo.saveMediaToVault(
            sourceFile: file,
            originalMessageId: msg.id,
            customFileName: null,
            senderName: senderName,
            senderId: msg.senderId,
            roomId: roomId,
          );
          savedCount++;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    onCompleted();

    if (savedCount > 0) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        savedCount == 1
            ? 'Berkas berhasil disimpan ke Brankas Berkas'
            : '$savedCount berkas berhasil disimpan ke Brankas Berkas',
      );
    } else {
      MekaarSnackbar.error(
        context,
        'Gagal memproses dan menyimpan berkas ke Brankas Berkas.',
      );
    }
  }
}
