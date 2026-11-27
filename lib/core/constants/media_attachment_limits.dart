/// Sumber kebenaran tunggal (Single Source of Truth) untuk batasan ketat
/// lampiran jamak & kebijakan retensi server Supabase Free Tier.
abstract final class MediaAttachmentLimits {
  /// Maksimal foto yang dapat dipilih & dikirim dalam satu batch.
  static const int maxImagesPerBatch = 4;

  /// Maksimal dokumen/berkas yang dapat dipilih & dikirim dalam satu batch.
  static const int maxDocumentsPerBatch = 3;

  /// Video hanya diizinkan pada pengiriman tunggal (tidak pada multi-pilih).
  static const bool allowVideoInMultiSelect = false;

  /// Batas maksimal ukuran per berkas untuk foto/dokumen/batch (10 MB).
  static const int maxSingleFileBytes = 10 * 1024 * 1024;

  /// Batas maksimal akumulasi ukuran seluruh berkas dalam 1 batch (20 MB).
  static const int maxTotalBatchBytes = 20 * 1024 * 1024;

  /// Batas keras bucket Supabase Storage `chat-media` (15 MB).
  static const int serverBucketHardLimitBytes = 15 * 1024 * 1024;

  /// Periode hapus otomatis berkas fisik di server Supabase Storage (7 hari).
  static const int serverRetentionDays = 7;

  /// Batas rate-limit unggah media per pengguna di sisi server.
  static const int serverUploadRateLimitCount = 20;
  static const int serverUploadRateLimitMinutes = 10;

  /// Memeriksa secara timezone-agnostic apakah objek media server telah melewati
  /// periode retensi otomatis ([serverRetentionDays] hari).
  static bool isServerMediaExpired(DateTime createdAt, {DateTime? now}) {
    final refNow = (now ?? DateTime.now()).toUtc();
    return refNow.difference(createdAt.toUtc()).inDays >= serverRetentionDays;
  }

  /// Pemberitahuan retensi server pada layar pratinjau kirim media.
  static String get retentionNotice =>
      'Demi privasi, media dihapus otomatis dari server setelah $serverRetentionDays hari (salinan lokal tetap aman).';

  /// Footnote ringkas pada bottom sheet lampiran chat.
  static String get attachmentSheetFootnote =>
      'Maks. $maxImagesPerBatch foto atau $maxDocumentsPerBatch berkas (10 MB/file) · Demi privasi, media dihapus dari server setelah $serverRetentionDays hari.';

  /// Pesan pemulihan yang jelas ketika media belum diunduh & telah dihapus dari server.
  static String get expiredMediaMessage =>
      'Media ini sudah dihapus otomatis dari server setelah $serverRetentionDays hari demi privasi. Berkas yang sudah diunduh atau disimpan di Brankas Berkas tetap aman di perangkat.';

  /// Penjelasan nilai penyimpanan permanen pada empty state Brankas Berkas.
  static String get vaultRetentionHint =>
      'Media di obrolan otomatis dihapus dari server setelah $serverRetentionDays hari. Simpan foto, rekaman suara, video, atau dokumen penting ke Brankas Berkas agar tetap tersimpan permanen dan terenkripsi di perangkat Anda.';

  /// Memformat ukuran byte menjadi representasi mudah baca (`B`, `KB`, `MB`).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Memvalidasi batch berkas terhadap batas jumlah item, ukuran per berkas,
  /// dan total ukuran seluruh batch secara deterministik.
  static ({List<T> accepted, List<String> warnings}) validateBatch<T>({
    required List<T> items,
    required int Function(T item) sizeOf,
    required String Function(T item) nameOf,
    required int maxItems,
    int maxFileBytes = maxSingleFileBytes,
    int maxTotalBytes = maxTotalBatchBytes,
  }) {
    final accepted = <T>[];
    final warnings = <String>[];

    final maxFileLabel = formatBytes(maxFileBytes);
    final maxTotalLabel = formatBytes(maxTotalBytes);

    var candidateList = items;
    if (items.length > maxItems) {
      candidateList = items.take(maxItems).toList();
      warnings.add(
        'Maksimal $maxItems lampiran per pengiriman. ${items.length - maxItems} berkas selebihnya dilewati.',
      );
    }

    var accumulatedBytes = 0;
    for (final item in candidateList) {
      final size = sizeOf(item);
      final name = nameOf(item);

      if (size > maxFileBytes) {
        warnings.add(
          '$name (${formatBytes(size)}) melebihi batas $maxFileLabel per berkas.',
        );
        continue;
      }

      if (accumulatedBytes + size > maxTotalBytes) {
        warnings.add(
          '$name dilewati karena total ukuran batch melebihi batas $maxTotalLabel.',
        );
        continue;
      }

      accepted.add(item);
      accumulatedBytes += size;
    }

    return (accepted: accepted, warnings: warnings);
  }
}
