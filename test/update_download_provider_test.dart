import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/providers/update_download_provider.dart';
import 'package:mekaar_chat/data/services/update_service.dart';

void main() {
  group('UpdateDownloadState Unit Tests', () {
    test('Inisialisasi default berstatus idle dan tidak minimized', () {
      const state = UpdateDownloadState();
      expect(state.status, equals(UpdateDownloadStatus.idle));
      expect(state.isDownloading, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.isCompleted, isFalse);
      expect(state.isMinimized, isFalse);
      expect(state.hasActiveTask, isFalse);
    });

    test('copyWith memperbarui nilai dan mempertahankan nilai lain', () {
      const state = UpdateDownloadState();
      final updated = state.copyWith(
        status: UpdateDownloadStatus.downloading,
        progress: 0.5,
        receivedBytes: 5000,
        totalBytes: 10000,
        isMinimized: true,
      );

      expect(updated.status, equals(UpdateDownloadStatus.downloading));
      expect(updated.isDownloading, isTrue);
      expect(updated.progress, equals(0.5));
      expect(updated.receivedBytes, equals(5000));
      expect(updated.totalBytes, equals(10000));
      expect(updated.isMinimized, isTrue);
      expect(updated.hasActiveTask, isTrue);
    });
  });

  group('UpdateDownloadController Unit Tests', () {
    test('minimize dan maximize mengubah flag isMinimized', () {
      final controller = UpdateDownloadController(UpdateService());
      expect(controller.state.isMinimized, isFalse);

      controller.minimize();
      expect(controller.state.isMinimized, isTrue);

      controller.maximize();
      expect(controller.state.isMinimized, isFalse);
    });

    test('markAutoPrompted dan resetAutoPrompt mengubah flag hasAutoPrompted', () {
      final controller = UpdateDownloadController(UpdateService());
      expect(controller.state.hasAutoPrompted, isFalse);

      controller.markAutoPrompted();
      expect(controller.state.hasAutoPrompted, isTrue);

      controller.resetAutoPrompt();
      expect(controller.state.hasAutoPrompted, isFalse);
    });

    test('dismiss mereset state ke kondisi idle awal', () {
      final controller = UpdateDownloadController(UpdateService());
      controller.minimize();
      expect(controller.state.isMinimized, isTrue);

      controller.dismiss();
      expect(controller.state.status, equals(UpdateDownloadStatus.idle));
      expect(controller.state.isMinimized, isFalse);
    });
  });
}
