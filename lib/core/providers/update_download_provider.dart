import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/update_service.dart';

enum UpdateDownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

enum InstallResult {
  success,
  permissionRequired,
  failed,
}

class UpdateDownloadState {
  final UpdateDownloadStatus status;
  final AppUpdateInfo? info;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? downloadedFilePath;
  final bool isMinimized;
  final bool hasAutoPrompted;
  final String? publicExportPath;
  final String? errorMessage;
  final String statusMessage;

  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.info,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.downloadedFilePath,
    this.isMinimized = false,
    this.hasAutoPrompted = false,
    this.publicExportPath,
    this.errorMessage,
    this.statusMessage = '',
  });

  bool get isDownloading => status == UpdateDownloadStatus.downloading;
  bool get isPaused => status == UpdateDownloadStatus.paused;
  bool get isCompleted => status == UpdateDownloadStatus.completed;
  bool get hasActiveTask =>
      status == UpdateDownloadStatus.downloading ||
      status == UpdateDownloadStatus.paused ||
      status == UpdateDownloadStatus.completed;

  UpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    AppUpdateInfo? info,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? downloadedFilePath,
    bool? isMinimized,
    bool? hasAutoPrompted,
    String? publicExportPath,
    String? errorMessage,
    String? statusMessage,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      info: info ?? this.info,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      isMinimized: isMinimized ?? this.isMinimized,
      hasAutoPrompted: hasAutoPrompted ?? this.hasAutoPrompted,
      publicExportPath: publicExportPath ?? this.publicExportPath,
      errorMessage: errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadController, UpdateDownloadState>((ref) {
  final updateService = ref.watch(updateServiceProvider);
  return UpdateDownloadController(updateService);
});

class UpdateDownloadController extends StateNotifier<UpdateDownloadState> {
  UpdateDownloadController(this._updateService)
      : super(const UpdateDownloadState());

  final UpdateService _updateService;
  int _lastUiUpdateTime = 0;
  bool _pauseRequested = false;

  /// Memulai atau melanjutkan proses unduhan APK pembaruan
  Future<void> startDownload(AppUpdateInfo updateInfo) async {
    if (state.isDownloading) return;
    _pauseRequested = false;

    final targetVersion = updateInfo.latestVersion;
    final expectedBytes = updateInfo.downloadSizeBytes;

    // Cek apakah file sudah 100% tersimpan sebelumnya
    final isAlreadyComplete = await _updateService.isApkFullyDownloaded(
      targetVersion,
      expectedBytes,
    );

    if (isAlreadyComplete) {
      final file = await _updateService.getUpdateFile(targetVersion);
      state = state.copyWith(
        status: UpdateDownloadStatus.completed,
        info: updateInfo,
        progress: 1.0,
        receivedBytes: expectedBytes > 0 ? expectedBytes : await file.length(),
        totalBytes: expectedBytes > 0 ? expectedBytes : await file.length(),
        downloadedFilePath: file.path,
        statusMessage: 'Pembaruan siap dipasang',
        errorMessage: null,
      );
      return;
    }

    // Periksa byte yang sudah tersimpan untuk resume
    final existingBytes =
        await _updateService.getDownloadedApkBytes(targetVersion);

    state = state.copyWith(
      status: UpdateDownloadStatus.downloading,
      info: updateInfo,
      receivedBytes: existingBytes,
      totalBytes: expectedBytes,
      progress: expectedBytes > 0
          ? (existingBytes / expectedBytes).clamp(0.0, 1.0)
          : 0.0,
      statusMessage: existingBytes > 0
          ? 'Melanjutkan unduhan...'
          : 'Mengunduh pembaruan...',
      errorMessage: null,
    );

    try {
      final file = await _updateService.downloadApk(
        downloadUrl: updateInfo.downloadUrl,
        version: targetVersion,
        expectedTotalBytes: expectedBytes,
        onProgress: (prog, received, total) {
          if (_pauseRequested) {
            throw Exception('PAUSED_BY_USER');
          }

          final now = DateTime.now().millisecondsSinceEpoch;
          final currentRec = math.max(state.receivedBytes, received);
          final currentTotal = total > 0 ? total : state.totalBytes;
          final currentProg =
              prog > 0 ? math.max(state.progress, prog) : state.progress;

          // Throttle state update ~60ms
          if ((now - _lastUiUpdateTime > 60) || prog >= 1.0) {
            _lastUiUpdateTime = now;
            final pct = (currentProg * 100).toInt();
            state = state.copyWith(
              receivedBytes: currentRec,
              totalBytes: currentTotal,
              progress: currentProg,
              statusMessage: currentProg >= 1.0
                  ? 'Pembaruan siap dipasang'
                  : 'Mengunduh $pct%...',
            );
          }
        },
      );

      state = state.copyWith(
        status: UpdateDownloadStatus.completed,
        progress: 1.0,
        downloadedFilePath: file.path,
        statusMessage: 'Pembaruan siap dipasang',
        errorMessage: null,
      );
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '').trim();
      if (errText == 'PAUSED_BY_USER' || _pauseRequested) {
        state = state.copyWith(
          status: UpdateDownloadStatus.paused,
          statusMessage: 'Unduhan dijeda',
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: UpdateDownloadStatus.error,
          errorMessage: errText,
          statusMessage: 'Unduhan terputus',
        );
      }
    }
  }

  /// Menjeda proses unduhan sementara
  void pauseDownload() {
    if (state.isDownloading) {
      _pauseRequested = true;
      state = state.copyWith(
        status: UpdateDownloadStatus.paused,
        statusMessage: 'Unduhan dijeda',
      );
    }
  }

  /// Meminimalkan bottom sheet ke floating pill tanpa memutus proses unduh
  void minimize() {
    state = state.copyWith(isMinimized: true);
  }

  /// Membuka kembali tampilan bottom sheet penuh dari floating pill
  void maximize() {
    state = state.copyWith(isMinimized: false);
  }

  /// Menandai bahwa prompt instalasi telah ditampilkan ke pengguna
  void markAutoPrompted() {
    state = state.copyWith(hasAutoPrompted: true);
  }

  /// Mereset flag auto prompt jika diperlukan
  void resetAutoPrompt() {
    state = state.copyWith(hasAutoPrompted: false);
  }

  /// Membuka file APK untuk instalasi paket native Android atau fallback jika gagal
  Future<InstallResult> triggerInstall() async {
    final path = state.downloadedFilePath;
    if (path == null) return InstallResult.failed;
    final file = File(path);
    if (!await file.exists()) return InstallResult.failed;

    // Periksa izin instalasi aplikasi tidak dikenal
    final canInstall = await _updateService.canRequestPackageInstalls();
    if (!canInstall) {
      await _updateService.openInstallPermissionSettings();
      return InstallResult.permissionRequired;
    }

    // Jalankan installer native Android langsung
    final success = await _updateService.installApk(path);
    if (success) {
      return InstallResult.success;
    }

    // Jika installer native gagal dibuka (misal restriksi vendor/OEM sistem),
    // ekspor APK ke folder Download publik sebagai fallback cadangan
    final ver = state.info?.latestVersion ?? 'update';
    final fileName = 'Mekaar-v$ver.apk';
    final publicPath =
        await _updateService.exportToPublicDownloads(path, fileName);
    if (publicPath != null) {
      state = state.copyWith(publicExportPath: publicPath);
    }
    return InstallResult.failed;
  }

  /// Membuka folder Download publik sistem Android
  Future<bool> openDownloadsFolder() async {
    return _updateService.openDownloadsFolder();
  }

  /// Membatalkan atau mereset unduhan
  void dismiss() {
    _pauseRequested = true;
    state = const UpdateDownloadState();
  }
}
