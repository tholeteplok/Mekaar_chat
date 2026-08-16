import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/update_service.dart';

void main() {
  group('UpdateService Version Comparison Tests', () {
    final updateService = UpdateService();

    test('Deteksi versi baru pada major bump', () {
      expect(updateService.isNewerVersion('2.0.0', '1.0.0'), isTrue);
      expect(updateService.isNewerVersion('v2.0.0', '1.0.0'), isTrue);
    });

    test('Deteksi versi baru pada minor bump', () {
      expect(updateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(updateService.isNewerVersion('v1.1.0', 'v1.0.9'), isTrue);
    });

    test('Deteksi versi baru pada patch bump', () {
      expect(updateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(updateService.isNewerVersion('v1.0.1', '1.0.0+1'), isTrue);
      expect(updateService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
    });

    test('Versi lama atau sama menghasilkan false', () {
      expect(updateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(updateService.isNewerVersion('v1.0.0', '1.0.0+1'), isFalse);
      expect(updateService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(updateService.isNewerVersion('1.0.0', '1.1.0'), isFalse);
    });

    test('Deteksi build number bump jika semver identik', () {
      expect(updateService.isNewerVersion('1.0.0+2', '1.0.0+1'), isTrue);
      expect(updateService.isNewerVersion('1.0.0+1', '1.0.0+2'), isFalse);
    });
  });
}
