import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Model representasi data yang dibagikan dari aplikasi eksternal (Android Send Intent)
class SharedPayload {
  final String? text;
  final List<String> filePaths;
  final List<SharedMediaFile> rawFiles;

  const SharedPayload({
    this.text,
    this.filePaths = const [],
    this.rawFiles = const [],
  });

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) && filePaths.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool get hasFiles => filePaths.isNotEmpty;
  bool get hasText => text != null && text!.trim().isNotEmpty;
}

/// StateNotifier untuk mengelola siklus hidup payload intent masuk
class ShareIntentNotifier extends StateNotifier<SharedPayload?> {
  StreamSubscription? _intentSub;

  ShareIntentNotifier() : super(null) {
    _init();
  }

  void _init() {
    try {
      // 1. Dengarkan intent yang masuk saat aplikasi sudah berjalan (background / singleTask)
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          _handleIncomingFiles(files);
        },
        onError: (err) {
          debugPrint('[ShareIntentService] getMediaStream error: $err');
        },
      );

      // 2. Periksa intent dingin (cold-start) saat aplikasi dibuka pertama kali lewat share menu
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) {
          _handleIncomingFiles(files);
        }
      }).catchError((err) {
        debugPrint('[ShareIntentService] getInitialMedia error: $err');
      });
    } catch (e) {
      debugPrint('[ShareIntentService] Inisialisasi intent listener gagal: $e');
    }
  }

  void _handleIncomingFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final StringBuffer textBuffer = StringBuffer();
    final List<String> paths = [];

    for (final file in files) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        if (textBuffer.isNotEmpty) textBuffer.writeln();
        textBuffer.write(file.path);
      } else {
        if (file.path.isNotEmpty) {
          paths.add(file.path);
        }
      }
      if (file.message != null && file.message!.trim().isNotEmpty) {
        if (textBuffer.isNotEmpty) textBuffer.writeln();
        textBuffer.write(file.message!.trim());
      }
    }

    final String? aggregatedText =
        textBuffer.isEmpty ? null : textBuffer.toString().trim();

    final payload = SharedPayload(
      text: aggregatedText,
      filePaths: paths,
      rawFiles: files,
    );

    if (payload.isNotEmpty) {
      state = payload;
      // Reset intent di platform native agar tidak memicu ulang saat resume
      ReceiveSharingIntent.instance.reset().catchError((_) => null);
    }
  }

  /// Pasang payload secara manual (digunakan untuk testing / injeksi)
  void setPayload(SharedPayload? payload) {
    state = payload;
  }

  /// Bersihkan payload setelah selesai dibagikan atau dibatalkan
  void clear() {
    state = null;
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }
}

/// Provider global untuk memantau keberadaan payload sharing yang belum diproses
final sharedPayloadProvider =
    StateNotifierProvider<ShareIntentNotifier, SharedPayload?>((ref) {
  return ShareIntentNotifier();
});
