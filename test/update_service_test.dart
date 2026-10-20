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

    test('Deteksi versi baru pada rollover transisi (max 99)', () {
      // Patch rollover ke minor berikutnya (v1.1.99 -> v1.2.0)
      expect(updateService.isNewerVersion('1.2.0', '1.1.99'), isTrue);
      expect(updateService.isNewerVersion('v1.2.0', 'v1.1.99'), isTrue);
      expect(updateService.isNewerVersion('1.1.99', '1.2.0'), isFalse);

      // Minor rollover ke major berikutnya (v1.99.99 -> v2.0.0)
      expect(updateService.isNewerVersion('2.0.0', '1.99.99'), isTrue);
      expect(updateService.isNewerVersion('v2.0.0', 'v1.99.99'), isTrue);
      expect(updateService.isNewerVersion('1.99.99', '2.0.0'), isFalse);
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

  group('UpdateService Smart ABI Matcher Tests', () {
    final updateService = UpdateService();
    final mockAssets = [
      {
        'name': 'Mekaar-v1.0.2-universal.apk',
        'browser_download_url': 'https://github.com/downloads/universal.apk',
        'size': 55 * 1024 * 1024,
      },
      {
        'name': 'Mekaar-v1.0.2-arm64-v8a.apk',
        'browser_download_url': 'https://github.com/downloads/arm64-v8a.apk',
        'size': 18 * 1024 * 1024,
      },
      {
        'name': 'Mekaar-v1.0.2-armeabi-v7a.apk',
        'browser_download_url': 'https://github.com/downloads/armeabi-v7a.apk',
        'size': 16 * 1024 * 1024,
      },
    ];

    test('Pilih arm64-v8a jika perangkat mendukung arm64-v8a', () {
      final matched = updateService.matchBestApkAsset(
        assets: mockAssets,
        supportedAbis: ['arm64-v8a', 'armeabi-v7a'],
      );

      expect(matched, isNotNull);
      expect(matched!['matchedAbi'], equals('arm64-v8a'));
      expect(
        (matched['asset'] as Map)['browser_download_url'],
        equals('https://github.com/downloads/arm64-v8a.apk'),
      );
    });

    test('Pilih armeabi-v7a jika perangkat hanya mendukung 32-bit', () {
      final matched = updateService.matchBestApkAsset(
        assets: mockAssets,
        supportedAbis: ['armeabi-v7a'],
      );

      expect(matched, isNotNull);
      expect(matched!['matchedAbi'], equals('armeabi-v7a'));
    });

    test('Fallback ke universal jika tidak ada ABI spesifik yang cocok', () {
      final matched = updateService.matchBestApkAsset(
        assets: mockAssets,
        supportedAbis: ['mips'],
      );

      expect(matched, isNotNull);
      expect(matched!['matchedAbi'], equals('universal'));
    });

    test('Format estimasi ukuran APK', () {
      expect(
        updateService.formatApkSize(18 * 1024 * 1024, isSplitAbi: true),
        contains('Hemat ~65%'),
      );
      expect(
        updateService.formatApkSize(55 * 1024 * 1024, isSplitAbi: false),
        equals('55.0 MB'),
      );
    });
  });

  group('UpdateService Release Notes Parser Tests', () {
    final updateService = UpdateService();

    test('Mem-parsing kategori fix, feat, perf, dan ui dari conventional commits', () {
      const raw = '''
# Changelog
* feat(chat): Tambahkan riwayat panggilan suara dan video
* fix(e2ee): Perbaiki loop dekripsi pesan
* perf(network): Optimasi bandwidth sinyal WebRTC
* ui(theme): Perbarui warna bubble riwayat panggilan
''';

      final items = updateService.parseReleaseNotes(raw);
      expect(items.length, equals(4));
      expect(items[0].category, equals(ReleaseCategory.feat));
      expect(items[0].text, equals('Tambahkan riwayat panggilan suara dan video'));
      expect(items[1].category, equals(ReleaseCategory.fix));
      expect(items[1].text, equals('Perbaiki loop dekripsi pesan'));
      expect(items[2].category, equals(ReleaseCategory.perf));
      expect(items[2].text, equals('Optimasi bandwidth sinyal WebRTC'));
      expect(items[3].category, equals(ReleaseCategory.ui));
      expect(items[3].text, equals('Perbarui warna bubble riwayat panggilan'));
    });

    test('Fallback default item jika raw notes kosong', () {
      final items = updateService.parseReleaseNotes('');
      expect(items.length, equals(1));
      expect(items.first.category, equals(ReleaseCategory.general));
      expect(items.first.text, contains('stabilitas'));
    });
  });
}

