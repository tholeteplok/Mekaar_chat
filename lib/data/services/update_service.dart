import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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
  static const MethodChannel _installerChannel =
      MethodChannel('com.mekaar.mekaar_chat/installer');

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

  /// Mendapatkan direktori penyimpanan berkas APK pembaruan
  Future<Directory> _getUpdateDir() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationSupportDirectory();
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }
    final updateDir = Directory('${baseDir.path}/updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  /// Mendapatkan referensi File APK pembaruan di penyimpanan persisten aplikasi (/updates/)
  Future<File> getUpdateFile(String version) async {
    final sanitizedVer =
        _sanitizeVersion(version).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final fileName = 'Mekaar-$sanitizedVer.apk';

    final updateDir = await _getUpdateDir();
    final primaryFile = File('${updateDir.path}/$fileName');
    if (await primaryFile.exists()) {
      return primaryFile;
    }

    // Periksa lokasi documents legacy jika berkas sudah ada sebelumnya
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${docsDir.path}/updates/$fileName');
      if (await legacyFile.exists()) {
        return legacyFile;
      }
    } catch (_) {}

    return primaryFile;
  }

  /// Membersihkan berkas APK versi lama di penyimpanan lokal
  Future<void> cleanupOldApkFiles(String currentKeepVersion) async {
    final sanitizedCurrent = _sanitizeVersion(currentKeepVersion)
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final currentFileName = 'Mekaar-$sanitizedCurrent.apk';

    void cleanInDir(Directory dir) {
      if (!dir.existsSync()) return;
      try {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.apk')) {
            final fileName = entity.uri.pathSegments.last;
            if (fileName != currentFileName) {
              try {
                entity.deleteSync();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    try {
      final dir = await _getUpdateDir();
      cleanInDir(dir);
    } catch (_) {}

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      cleanInDir(Directory('${docsDir.path}/updates'));
    } catch (_) {}
  }

  /// Memeriksa berapa byte file APK yang sudah tersimpan di penyimpanan persisten untuk versi tertentu
  Future<int> getDownloadedApkBytes(String version) async {
    try {
      final saveFile = await getUpdateFile(version);
      if (await saveFile.exists()) {
        return await saveFile.length();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Memeriksa apakah file APK untuk versi tertentu sudah selesai diunduh 100%
  Future<bool> isApkFullyDownloaded(String version, int expectedBytes) async {
    try {
      final saveFile = await getUpdateFile(version);
      if (!await saveFile.exists()) return false;
      final len = await saveFile.length();
      if (expectedBytes > 0) {
        return len >= expectedBytes;
      }
      return len > 0;
    } catch (_) {
      return false;
    }
  }

  /// Mengunduh file APK langsung ke penyimpanan persisten aplikasi dengan dukungan Resumable Download (HTTP Range)
  /// dan pemulihan otomatis (Auto-Retry) jika koneksi terputus.
  Future<File> downloadApk({
    required String downloadUrl,
    required String version,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
    int? expectedTotalBytes,
  }) async {
    await cleanupOldApkFiles(version);
    final saveFile = await getUpdateFile(version);

    // Periksa file yang sudah ada sebelumnya untuk melanjutkan
    int existingBytes = 0;
    if (await saveFile.exists()) {
      final len = await saveFile.length();
      if (expectedTotalBytes != null &&
          expectedTotalBytes > 0 &&
          len >= expectedTotalBytes) {
        // File sudah lengkap 100% di penyimpanan
        onProgress(1.0, len, expectedTotalBytes);
        return saveFile;
      }
      existingBytes = len;
    }

    int retryCount = 0;
    const maxRetries = 3;

    while (true) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      client.idleTimeout = const Duration(seconds: 35);
      client.autoUncompress = false;
      IOSink? sink;

      try {
        if (await saveFile.exists()) {
          existingBytes = await saveFile.length();
        } else {
          existingBytes = 0;
        }

        var currentUrl = downloadUrl;
        HttpClientResponse? response;

        // Tangani redirect chain (301, 302, 307, 308) seperti GitHub S3 AWS CDN
        for (int i = 0; i < 6; i++) {
          final request = await client.getUrl(Uri.parse(currentUrl));
          request.headers.set(HttpHeaders.userAgentHeader, 'Mekaar-Chat-App');
          request.headers.set(HttpHeaders.acceptHeader, '*/*');
          request.followRedirects = false;

          // Kirim header Range jika sudah memiliki sebagian data
          if (existingBytes > 0) {
            request.headers
                .set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
          }

          final res = await request.close();
          if (res.isRedirect ||
              res.statusCode == HttpStatus.movedPermanently ||
              res.statusCode == HttpStatus.found ||
              res.statusCode == HttpStatus.seeOther ||
              res.statusCode == HttpStatus.temporaryRedirect) {
            final location = res.headers.value(HttpHeaders.locationHeader);
            if (location != null && location.isNotEmpty) {
              currentUrl = location;
              continue;
            }
          }
          response = res;
          break;
        }

        if (response == null) {
          throw Exception('Tidak mendapatkan respons dari server pembaruan.');
        }

        final statusCode = response.statusCode;

        // Jika server mengembalikan 416 (Range Not Satisfiable), file mungkin sudah lengkap
        if (statusCode == HttpStatus.requestedRangeNotSatisfiable &&
            existingBytes > 0) {
          onProgress(1.0, existingBytes, expectedTotalBytes ?? existingBytes);
          return saveFile;
        }

        if (statusCode != HttpStatus.ok &&
            statusCode != HttpStatus.partialContent) {
          throw Exception('Gagal mengunduh file APK (HTTP $statusCode)');
        }

        final isPartial = statusCode == HttpStatus.partialContent;
        final headerContentLength = response.contentLength;

        // Kalkulasi total byte efektif
        final int effectiveTotalBytes;
        if (isPartial) {
          effectiveTotalBytes = expectedTotalBytes ??
              (headerContentLength > 0
                  ? existingBytes + headerContentLength
                  : existingBytes);
        } else {
          // Server mengirim dari awal
          effectiveTotalBytes = headerContentLength > 0
              ? headerContentLength
              : (expectedTotalBytes ?? 0);
          existingBytes = 0;
        }

        sink = saveFile.openWrite(
            mode: isPartial ? FileMode.append : FileMode.write);
        int receivedBytes = existingBytes;

        if (effectiveTotalBytes > 0) {
          final initialProgress =
              (receivedBytes / effectiveTotalBytes).clamp(0.0, 1.0);
          onProgress(initialProgress, receivedBytes, effectiveTotalBytes);
        }

        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (effectiveTotalBytes > 0) {
            final progress =
                (receivedBytes / effectiveTotalBytes).clamp(0.0, 1.0);
            onProgress(progress, receivedBytes, effectiveTotalBytes);
          } else {
            onProgress(-1.0, receivedBytes, 0);
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        return saveFile;
      } catch (e) {
        try {
          await sink?.close();
        } catch (_) {}
        sink = null;

        retryCount++;
        if (retryCount <= maxRetries) {
          // Tunggu sebentar lalu coba sambung ulang (auto-retry)
          await Future<void>.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }

        final sanitized = _sanitizeErrorMessage(
          e.toString(),
          existingBytes,
          expectedTotalBytes,
        );
        throw Exception(sanitized);
      } finally {
        client.close();
      }
    }
  }

  /// Membersihkan pesan error unduhan dari string URL teknis AWS yang panjang
  String _sanitizeErrorMessage(
    String rawError,
    int downloadedBytes,
    int? totalBytes,
  ) {
    final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes != null && totalBytes > 0)
        ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : 'ukuran penuh';

    if (rawError.contains('Connection closed') ||
        rawError.contains('SocketException') ||
        rawError.contains('ClientException') ||
        rawError.contains('TimeoutException') ||
        rawError.contains('HttpException')) {
      return 'Koneksi terputus saat mengunduh ($downloadedMb MB tersimpan dari $totalMb). Anda dapat melanjutkan unduhan kapan saja.';
    }

    final clean = rawError.replaceAll(RegExp(r'\?[^ ]+'), '');
    return clean.replaceFirst('Exception: ', '').trim();
  }

  /// Membuka file APK untuk instalasi melalui Android Package Installer
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _installerChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('[UpdateService] Gagal memanggil installApk: $e');
      return false;
    }
  }

  /// Memeriksa apakah aplikasi memiliki izin memasang APK tidak dikenal (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Membuka pengaturan sistem untuk mengaktifkan izin pemasangan APK
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _installerChannel
          .invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Menyalin file APK ke folder Download publik Android sebagai fallback
  Future<String?> exportToPublicDownloads(
      String filePath, String fileName) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _installerChannel.invokeMethod<String>(
        'exportToPublicDownloads',
        {'filePath': filePath, 'fileName': fileName},
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Membuka aplikasi Pengelola File / Download Manager sistem Android
  Future<bool> openDownloadsFolder() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _installerChannel.invokeMethod<bool>('openDownloadsFolder');
      return result ?? false;
    } catch (_) {
      return false;
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
      final lNum =
          i < latestSemver.length ? int.tryParse(latestSemver[i]) ?? 0 : 0;
      final cNum =
          i < currentSemver.length ? int.tryParse(currentSemver[i]) ?? 0 : 0;

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

  /// Mem-parsing catatan rilis mentah menjadi daftar item terstruktur ramah pengguna
  List<ReleaseNoteItem> parseReleaseNotes(String rawNotes) {
    final cleanNotes = rawNotes.trim();
    final items = <ReleaseNoteItem>[];

    if (cleanNotes.isNotEmpty) {
      final lines = cleanNotes.split('\n');
      for (final rawLine in lines) {
        var line = rawLine.trim();
        if (line.isEmpty) continue;

        // Bersihkan header markdown dan tautan teknis repositori
        if (line.startsWith('#') ||
            line.toLowerCase().contains('full changelog') ||
            line.toLowerCase().contains('compare/')) {
          continue;
        }

        // Hapus bullet markdown
        if (line.startsWith('- ') || line.startsWith('* ')) {
          line = line.substring(2).trim();
        }

        if (line.isEmpty) continue;

        // Deteksi kategori release
        final lower = line.toLowerCase();
        ReleaseCategory category = ReleaseCategory.general;
        if (lower.startsWith('fix:') || lower.startsWith('fix(')) {
          category = ReleaseCategory.fix;
        } else if (lower.startsWith('feat:') || lower.startsWith('feat(')) {
          category = ReleaseCategory.feat;
        } else if (lower.startsWith('perf:') || lower.startsWith('perf(')) {
          category = ReleaseCategory.perf;
        } else if (lower.startsWith('ui:') ||
            lower.startsWith('ui(') ||
            lower.startsWith('style:') ||
            lower.startsWith('style(')) {
          category = ReleaseCategory.ui;
        } else if (lower.contains('bug') || lower.contains('perbaikan')) {
          category = ReleaseCategory.fix;
        } else if (lower.contains('fitur baru') ||
            lower.contains('fitur') ||
            lower.contains('penambahan')) {
          category = ReleaseCategory.feat;
        } else if (lower.contains('kecepatan') || lower.contains('optimasi')) {
          category = ReleaseCategory.perf;
        } else if (lower.contains('tampilan') || lower.contains('desain')) {
          category = ReleaseCategory.ui;
        }

        // Buang prefix conventional commit seperti "feat(chat): "
        line = line.replaceFirst(RegExp(r'^[a-zA-Z]+(\([^\)]+\))?:\s*'), '');

        items.add(ReleaseNoteItem(category: category, text: line));
      }
    }

    if (items.isEmpty) {
      items.add(
        const ReleaseNoteItem(
          category: ReleaseCategory.general,
          text: 'Pembaruan stabilitas, performa, dan penguatan privasi MEKAAR.',
        ),
      );
    }

    return items;
  }
}

enum ReleaseCategory { fix, feat, perf, ui, general }

class ReleaseNoteItem {
  final ReleaseCategory category;
  final String text;

  const ReleaseNoteItem({
    required this.category,
    required this.text,
  });
}
