import 'dart:io';

/// Tipe media yang disimpan di dalam Brankas Berkas.
enum VaultFileType {
  image,
  video,
  audio,
  document,
  other;

  String get displayName {
    switch (this) {
      case VaultFileType.image:
        return 'Gambar';
      case VaultFileType.video:
        return 'Video';
      case VaultFileType.audio:
        return 'Audio';
      case VaultFileType.document:
        return 'Dokumen';
      case VaultFileType.other:
        return 'Lainnya';
    }
  }

  static VaultFileType fromString(String? type) {
    if (type == null) return VaultFileType.other;
    return VaultFileType.values.firstWhere(
      (e) => e.name.toLowerCase() == type.toLowerCase(),
      orElse: () => VaultFileType.other,
    );
  }

  static VaultFileType fromFileNameOrMime(String fileName, {String? mimeType}) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return VaultFileType.image;
    if (mime.startsWith('video/')) return VaultFileType.video;
    if (mime.startsWith('audio/')) return VaultFileType.audio;
    if (mime.contains('pdf') ||
        mime.contains('document') ||
        mime.contains('word') ||
        mime.contains('excel') ||
        mime.contains('sheet') ||
        mime.contains('presentation') ||
        mime.contains('text/plain')) {
      return VaultFileType.document;
    }

    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'heic':
        return VaultFileType.image;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'webm':
      case '3gp':
        return VaultFileType.video;
      case 'mp3':
      case 'm4a':
      case 'aac':
      case 'wav':
      case 'ogg':
      case 'opus':
        return VaultFileType.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
      case 'txt':
      case 'csv':
        return VaultFileType.document;
      default:
        return VaultFileType.other;
    }
  }
}

/// Model data berkas rahasia yang disimpan dalam Brankas Berkas Mekaar.
class VaultItem {
  final String id;
  final String? originalMessageId;
  final String fileName;
  final VaultFileType fileType;
  final String localPath;
  final int fileSizeBytes;
  final String? mimeType;
  final String? senderName;
  final String? senderId;
  final String? roomId;
  final DateTime savedAt;

  const VaultItem({
    required this.id,
    this.originalMessageId,
    required this.fileName,
    required this.fileType,
    required this.localPath,
    required this.fileSizeBytes,
    this.mimeType,
    this.senderName,
    this.senderId,
    this.roomId,
    required this.savedAt,
  });

  /// Format ukuran file yang mudah dibaca pengguna (misal 1.2 MB, 450 KB).
  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Cek apakah file fisik masih ada di disk lokal.
  bool existsOnDisk() {
    try {
      return File(localPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_message_id': originalMessageId,
      'file_name': fileName,
      'file_type': fileType.name,
      'local_path': localPath,
      'file_size': fileSizeBytes,
      'mime_type': mimeType,
      'sender_name': senderName,
      'sender_id': senderId,
      'room_id': roomId,
      'saved_at': savedAt.toIso8601String(),
    };
  }

  factory VaultItem.fromMap(Map<String, dynamic> map) {
    return VaultItem(
      id: map['id'] as String,
      originalMessageId: map['original_message_id'] as String?,
      fileName: map['file_name'] as String? ?? 'Berkas Tanpa Nama',
      fileType: VaultFileType.fromString(map['file_type'] as String?),
      localPath: map['local_path'] as String? ?? '',
      fileSizeBytes: (map['file_size'] as num?)?.toInt() ?? 0,
      mimeType: map['mime_type'] as String?,
      senderName: map['sender_name'] as String?,
      senderId: map['sender_id'] as String?,
      roomId: map['room_id'] as String?,
      savedAt: map['saved_at'] != null
          ? DateTime.tryParse(map['saved_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  VaultItem copyWith({
    String? id,
    String? originalMessageId,
    String? fileName,
    VaultFileType? fileType,
    String? localPath,
    int? fileSizeBytes,
    String? mimeType,
    String? senderName,
    String? senderId,
    String? roomId,
    DateTime? savedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      originalMessageId: originalMessageId ?? this.originalMessageId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      senderName: senderName ?? this.senderName,
      senderId: senderId ?? this.senderId,
      roomId: roomId ?? this.roomId,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
