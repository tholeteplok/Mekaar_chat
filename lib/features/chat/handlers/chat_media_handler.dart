import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc;
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/utils/message_preview_resolver.dart';
import '../../../core/widgets/bubbles/bubble_media_helper.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/services/media_upload_service.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/document_send_preview_sheet.dart';
import '../widgets/image_send_preview_sheet.dart';

/// Handler terisolasi untuk pipeline media (gambar, berkas dokumen),
/// share intent berkas, serta pengiriman sensor lokasi GPS & live location.
class ChatMediaHandler {
  const ChatMediaHandler._();

  /// Menangani daftar berkas yang diterima dari share intent atau drag-drop
  /// dengan menampilkan pratinjau sebelum dikirim.
  static Future<void> handleInitialSharedFiles(
    BuildContext context, {
    required WidgetRef ref,
    required List<String> filePaths,
    required Future<void> Function(
      File file,
      MessageType type, {
      String? caption,
      bool? isViewOnce,
    })
    onSendMedia,
  }) async {
    for (final path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final mimeType = lookupMimeType(path) ?? '';
      final chatPref =
          ref.read(chatThemeProvider).valueOrNull ??
          const ChatThemePreference();
      if (!context.mounted) return;
      final spec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);

      if (mimeType.startsWith('image/')) {
        if (!context.mounted) return;
        final result = await Navigator.of(context).push<ImageSendResult>(
          MaterialPageRoute(
            builder: (_) =>
                ImageSendPreviewSheet(imageFile: file, roomThemeSpec: spec),
          ),
        );
        if (result != null && context.mounted) {
          await onSendMedia(
            result.file,
            MessageType.image,
            caption: result.caption,
            isViewOnce: result.isViewOnce,
          );
        }
      } else {
        final fileName = path.split(Platform.pathSeparator).last;
        final fileSize = await file.length();
        if (!context.mounted) return;
        final result = await Navigator.of(context).push<DocumentSendResult>(
          MaterialPageRoute(
            builder: (_) => DocumentSendPreviewSheet(
              file: file,
              fileName: fileName,
              fileSize: fileSize,
              roomThemeSpec: spec,
            ),
          ),
        );
        if (result != null && context.mounted) {
          await onSendMedia(
            result.file,
            MessageType.file,
            caption: result.caption,
          );
        }
      }
    }
  }

  /// Mengunggah media ke Supabase Storage (dengan enkripsi E2EE jika peer key tersedia)
  /// dan mengirim pesan media ke ruang obrolan.
  static Future<void> sendMedia(
    BuildContext context, {
    required WidgetRef ref,
    required String chatId,
    required bool isGroup,
    required String? otherUserId,
    required File file,
    required MessageType type,
    String? caption,
    bool? isViewOnce,
    Message? replyMessage,
    required int autoDeleteHours,
    required DateTime? scheduledWipeTargetAt,
    required VoidCallback onScrollToBottom,
    VoidCallback? onAfterSend,
  }) async {
    String? uploadedUrl;
    final uploader = MediaUploadService(Supabase.instance.client);

    try {
      String? fileKeyB64;
      String url;

      // Periksa apakah kamar mendukung E2EE (peer key tersedia) tanpa enkripsi dummy yang boros
      final peerKey = otherUserId != null
          ? await E2eeService.instance.getPeerPublicKey(otherUserId)
          : null;
      if (peerKey != null && peerKey.isNotEmpty) {
        // Kamar chat mendukung E2EE, enkripsi & unggah media
        final result = await uploader.uploadEncryptedChatMedia(file, chatId);
        url = result.url;
        fileKeyB64 = result.keyB64;
      } else {
        // Fallback: unggah biasa
        url = await uploader.uploadChatMedia(file, chatId);
      }

      uploadedUrl = url;
      final isViewOnceToSend = isViewOnce ?? false;

      final trimmedCaption = caption?.trim();
      String contentPayload;
      if (type == MessageType.file) {
        final originalFileName = file.path.split(Platform.pathSeparator).last;
        final fileSize = await file.length();
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';
        contentPayload = FileAttachmentMeta(
          fileName: originalFileName,
          fileSize: fileSize,
          mimeType: mimeType,
          keyB64: fileKeyB64,
          caption: trimmedCaption,
        ).toContentJson();
      } else if (fileKeyB64 != null && fileKeyB64.isNotEmpty) {
        if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
          contentPayload = jsonEncode({
            'key': fileKeyB64,
            'caption': trimmedCaption,
          });
        } else {
          contentPayload = fileKeyB64;
        }
      } else {
        contentPayload = trimmedCaption ?? '';
      }

      final replyId = replyMessage?.id;

      final sentMsg = await ref
          .read(chatActionsProvider)
          .sendMessage(
            chatId,
            contentPayload,
            mediaUrl: url,
            type: type,
            isViewOnce: isViewOnceToSend,
            replyToId: replyId,
            autoDeleteHours: autoDeleteHours,
            scheduledWipeTargetAt: scheduledWipeTargetAt,
            isGroup: isGroup,
          );

      // Daftarkan langsung berkas lokal ke memory & disk cache agar tidak berkedip
      registerLocalMedia(sentMsg.id, file, url: url);

      ref
          .read(chatRoomsProvider.notifier)
          .updateLastMessageLocally(
            roomId: chatId,
            previewText: MessagePreviewResolver.formatChatListPreview(
              type: type,
              content: contentPayload,
              isUnreadFromOther: false,
            ),
            timestamp: DateTime.now(),
            isFromOtherUser: false,
            isCurrentlyInRoom: true,
          );

      onAfterSend?.call();
      onScrollToBottom();
    } catch (e) {
      // Pembersihan media remote jika pembuatan pesan gagal
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        try {
          await uploader.deleteMediaByUrl(uploadedUrl);
        } catch (_) {}
      }
      if (context.mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mengirim media: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  /// Membaca koordinat GPS pengguna dan mengirimkan pesan lokasi ke ruang obrolan.
  static Future<void> sendLocation(
    BuildContext context, {
    required WidgetRef ref,
    required String chatId,
    required bool isGroup,
    required int autoDeleteHours,
    required DateTime? scheduledWipeTargetAt,
    required VoidCallback onScrollToBottom,
  }) async {
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) return;
      }

      final locationData = await location.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      if (lat == null || lng == null) return;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            chatId,
            '$lat, $lng',
            type: MessageType.location,
            autoDeleteHours: autoDeleteHours,
            scheduledWipeTargetAt: scheduledWipeTargetAt,
            isGroup: isGroup,
          );

      ref
          .read(chatRoomsProvider.notifier)
          .updateLastMessageLocally(
            roomId: chatId,
            previewText: MessagePreviewResolver.formatChatListPreview(
              type: MessageType.location,
              content: '$lat, $lng',
              isUnreadFromOther: false,
            ),
            timestamp: DateTime.now(),
            isFromOtherUser: false,
            isCurrentlyInRoom: true,
          );
      onScrollToBottom();
    } catch (e) {
      if (context.mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mendapatkan lokasi: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  /// Memulai sesi berbagi live location terenkripsi.
  static Future<void> shareLiveLocation(
    BuildContext context, {
    required WidgetRef ref,
    required String chatId,
    required int durationMinutes,
  }) async {
    try {
      await ref
          .read(chatActionsProvider)
          .shareLiveLocation(chatId, durationMinutes);
      if (context.mounted) {
        HapticService.trigger(MekaarHapticIntent.success);
        MekaarSnackbar.success(
          context,
          'Lokasi live dibagikan selama $durationMinutes menit',
        );
      }
    } catch (e) {
      if (context.mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal membagikan lokasi live: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }
}
