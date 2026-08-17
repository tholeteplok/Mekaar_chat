import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// Model data status pembaruan aplikasi
class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;
  final String matchedAbi;
  final int downloadSizeBytes;
  final String formattedSize;
  final DateTime? publishedAt;
  final String? errorMessage;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
    this.matchedAbi = 'universal',
    this.downloadSizeBytes = 0,
    this.formattedSize = '',
    this.publishedAt,
    this.errorMessage,
  });

  factory AppUpdateInfo.upToDate(String currentVersion) {
    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseName: '',
      releaseNotes: '',
      downloadUrl: '',
      htmlUrl: 'https://github.com/tholeteplok/Mekaar_chat/releases',
    );
  }

  factory AppUpdateInfo.error(String currentVersion, String message) {
    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseName: '',
      releaseNotes: '',
      downloadUrl: '',
      htmlUrl: 'https://github.com/tholeteplok/Mekaar_chat/releases',
      errorMessage: message,
    );
  }
}

class UpdateService {
  static const String _repoOwner = 'tholeteplok';
  static const String _repoName = 'Mekaar_chat';
  static const String _githubApiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// Mendapatkan versi aplikasi saat ini dari metadata package info
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '1.0.0+1';
    }
  }

  /// Mendapatkan daftar ABI arsitektur CPU yang didukung perangkat Android
  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const ['universal'];
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.supportedAbis;
    } catch (_) {
      return const ['arm64-v8a', 'armeabi-v7a'];
    }
  }

  /// Format estimasi ukuran APK
  String formatApkSize(int bytes, {bool isSplitAbi = false}) {
    if (bytes <= 0) return isSplitAbi ? '~18 MB' : '~55 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 30) {
      return '${mb.toStringAsFixed(1)} MB · Hemat ~65%';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Mencocokkan asset APK rilis terbaik berdasarkan arsitektur CPU perangkat (ABI)
  Map<String, dynamic>? matchBestApkAsset({
    required List<dynamic> assets,
    required List<String> supportedAbis,
  }) {
    if (assets.isEmpty) return null;

    final apkAssets = assets.where((a) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      return name.endsWith('.apk');
    }).toList();

    if (apkAssets.isEmpty) return null;

    // 1. Cek kecocokan prioritas ABI perangkat (dimulai dari ABI utama misal arm64-v8a)
    for (final abi in supportedAbis) {
      final normalizedAbi = abi.toLowerCase().trim();
      for (final asset in apkAssets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains(normalizedAbi)) {
          return {
            'asset': asset,
            'matchedAbi': normalizedAbi,
          };
        }
      }
    }

    // 2. Cek universal APK jika ada
    for (final asset in apkAssets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('universal')) {
        return {
          'asset': asset,
          'matchedAbi': 'universal',
        };
      }
    }

    // 3. Fallback ke APK pertama yang ditemukan
    return {
      'asset': apkAssets.first,
      'matchedAbi': 'universal',
    };
  }

  /// Memeriksa rilis terbaru dari GitHub Releases API dengan Smart ABI Matching
  Future<AppUpdateInfo> checkForUpdate({
    String? currentVersionOverride,
    List<String>? supportedAbisOverride,
  }) async {
    final currentVersion = currentVersionOverride ?? await getCurrentVersion();
    final supportedAbis = supportedAbisOverride ?? await getSupportedAbis();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse(_githubApiUrl);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mekaar-Chat-App');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github.v3+json');

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        final tagName = (json['tag_name'] as String? ?? '').trim();
        final releaseName = (json['name'] as String? ?? tagName).trim();
        final body = (json['body'] as String? ?? '').trim();
        final htmlUrl = (json['html_url'] as String? ??
                'https://github.com/$_repoOwner/$_repoName/releases')
            .trim();
        final publishedAtStr = json['published_at'] as String?;
        final publishedAt = publishedAtStr != null
            ? DateTime.tryParse(publishedAtStr)
            : null;

        // Cari URL unduhan APK terbaik sesuai arsitektur CPU (Smart ABI Match)
        String downloadUrl = htmlUrl;
        String matchedAbi = 'universal';
        int downloadSizeBytes = 0;
        String formattedSize = '';

        final assets = json['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          final matched = matchBestApkAsset(
            assets: assets,
            supportedAbis: supportedAbis,
          );

          if (matched != null) {
            final asset = matched['asset'] as Map<String, dynamic>;
            downloadUrl = asset['browser_download_url'] as String? ?? htmlUrl;
            matchedAbi = matched['matchedAbi'] as String? ?? 'universal';
            downloadSizeBytes = asset['size'] as int? ?? 0;
            formattedSize = formatApkSize(
              downloadSizeBytes,
              isSplitAbi: matchedAbi != 'universal',
            );
          }
        }

        final latestVersionClean = _sanitizeVersion(tagName);
        final hasUpdate = isNewerVersion(latestVersionClean, currentVersion);

        return AppUpdateInfo(
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          latestVersion: tagName.isNotEmpty ? tagName : latestVersionClean,
          releaseName: releaseName,
          releaseNotes: body.isNotEmpty
              ? body
              : 'Pembaruan stabilitas, performa, dan penguatan keamanan aplikasi MEKAAR.',
          downloadUrl: downloadUrl,
          htmlUrl: htmlUrl,
          matchedAbi: matchedAbi,
          downloadSizeBytes: downloadSizeBytes,
          formattedSize: formattedSize,
          publishedAt: publishedAt,
        );
      } else if (response.statusCode == 404) {
        // Belum ada rilis publik di GitHub
        return AppUpdateInfo.upToDate(currentVersion);
      } else {
        return AppUpdateInfo.error(
          currentVersion,
          'Gagal memeriksa pembaruan (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      return AppUpdateInfo.error(
        currentVersion,
        'Tidak dapat terhubung ke server pembaruan: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Membersihkan prefix 'v' dan whitespace dari string versi
  String _sanitizeVersion(String version) {
    var clean = version.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    return clean;
  }

  /// Membandingkan dua string SemVer (misal "1.1.0" vs "1.0.0+1")
  /// Mengembalikan true jika [latestVersion] lebih baru daripada [currentVersion].
  bool isNewerVersion(String latestVersion, String currentVersion) {
    final cleanLatest = _sanitizeVersion(latestVersion);
    final cleanCurrent = _sanitizeVersion(currentVersion);

    // Pisahkan versi utama dan build number (misal "1.0.0+1" -> "1.0.0" dan 1)
    final latestParts = cleanLatest.split('+');
    final currentParts = cleanCurrent.split('+');

    final latestSemver = latestParts[0].split('.');
    final currentSemver = currentParts[0].split('.');

    final maxLen = latestSemver.length > currentSemver.length
        ? latestSemver.length
        : currentSemver.length;

    for (int i = 0; i < maxLen; i++) {
      final lNum = i < latestSemver.length ? int.tryParse(latestSemver[i]) ?? 0 : 0;
      final cNum = i < currentSemver.length ? int.tryParse(currentSemver[i]) ?? 0 : 0;

      if (lNum > cNum) return true;
      if (lNum < cNum) return false;
    }

    // Jika major.minor.patch sama, periksa build number jika ada
    if (latestParts.length > 1 && currentParts.length > 1) {
      final lBuild = int.tryParse(latestParts[1]) ?? 0;
      final cBuild = int.tryParse(currentParts[1]) ?? 0;
      if (lBuild > cBuild) return true;
    }

    return false;
  }
}
