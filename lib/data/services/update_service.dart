import 'dart:convert';
import 'dart:io';
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

  /// Memeriksa rilis terbaru dari GitHub Releases API
  Future<AppUpdateInfo> checkForUpdate({String? currentVersionOverride}) async {
    final currentVersion = currentVersionOverride ?? await getCurrentVersion();

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

        // Cari URL unduhan APK dari daftar assets rilis
        String downloadUrl = htmlUrl;
        final assets = json['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
              break;
            }
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
