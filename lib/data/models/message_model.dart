import 'dart:convert';

enum MessageType { text, image, voice, video, system, location, file }

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String? mediaUrl;
  final MessageType type;
  final bool isViewOnce;
  final bool isOpened;
  final DateTime? openedAt;
  final String? replyToId;
  final bool isDeleted;
  final bool isSilentDeleted;
  final DateTime? autoDeleteAt;
  final DateTime? editedAt;
  // Map of emoji → list of user IDs who reacted (e.g. {"👍": ["uid1","uid2"]})
  final Map<String, List<String>> reactions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEncrypted;
  final bool isSending;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.mediaUrl,
    required this.type,
    this.isViewOnce = false,
    this.isOpened = false,
    this.openedAt,
    this.replyToId,
    this.isDeleted = false,
    this.isSilentDeleted = false,
    this.isEncrypted = false,
    this.isSending = false,
    this.autoDeleteAt,
    this.editedAt,
    this.reactions = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEdited => editedAt != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse message type safely
    MessageType mType = MessageType.text;
    final jsonType = json['msg_type'] as String?;
    if (jsonType != null) {
      mType = MessageType.values.firstWhere(
        (e) => e.name == jsonType,
        orElse: () => MessageType.text,
      );
    }

    // Parse reactions JSONB: {"👍": ["uid1", "uid2"]}
    Map<String, List<String>> parsedReactions = {};
    final rawReactions = json['reactions'];
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value is List) {
          parsedReactions[key.toString()] = value
              .map((e) => e.toString())
              .toList();
        }
      });
    }

    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      type: mType,
      isViewOnce: json['is_view_once'] as bool? ?? false,
      isOpened: json['is_opened'] as bool? ?? false,
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'] as String)
          : null,
      replyToId: json['reply_to_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      isSilentDeleted: json['is_silent_deleted'] as bool? ?? false,
      autoDeleteAt: json['auto_delete_at'] != null
          ? DateTime.parse(json['auto_delete_at'] as String)
          : null,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      reactions: parsedReactions,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isEncrypted: json['is_encrypted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'media_url': mediaUrl,
      'msg_type': type.name,
      'is_view_once': isViewOnce,
      'is_opened': isOpened,
      'opened_at': openedAt?.toIso8601String(),
      'reply_to_id': replyToId,
      'is_deleted': isDeleted,
      'is_silent_deleted': isSilentDeleted,
      'auto_delete_at': autoDeleteAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'reactions': reactions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_encrypted': isEncrypted,
    };
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? content,
    String? mediaUrl,
    MessageType? type,
    bool? isViewOnce,
    bool? isOpened,
    DateTime? openedAt,
    String? replyToId,
    bool? isDeleted,
    bool? isSilentDeleted,
    DateTime? autoDeleteAt,
    DateTime? editedAt,
    Map<String, List<String>>? reactions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEncrypted,
    bool? isSending,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      type: type ?? this.type,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      isOpened: isOpened ?? this.isOpened,
      openedAt: openedAt ?? this.openedAt,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      isSilentDeleted: isSilentDeleted ?? this.isSilentDeleted,
      autoDeleteAt: autoDeleteAt ?? this.autoDeleteAt,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isSending: isSending ?? this.isSending,
    );
  }

  /// Metadata lampiran berkas jika pesan bertipe [MessageType.file].
  FileAttachmentMeta? get fileMeta =>
      type == MessageType.file ? FileAttachmentMeta.fromContent(content) : null;
}

/// Metadata terenkripsi untuk lampiran berkas dokumen pada pesan chat.
class FileAttachmentMeta {
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final String? keyB64;
  final String? caption;

  const FileAttachmentMeta({
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    this.keyB64,
    this.caption,
  });

  factory FileAttachmentMeta.fromContent(String content, {String? fallbackName}) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        return FileAttachmentMeta(
          fileName: map['file_name'] as String? ?? fallbackName ?? 'Berkas Dokumen',
          fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
          mimeType: map['mime_type'] as String?,
          keyB64: map['key'] as String?,
          caption: map['caption'] as String?,
        );
      } catch (_) {}
    }
    return FileAttachmentMeta(
      fileName: fallbackName ?? 'Berkas Dokumen',
      fileSize: 0,
      caption: trimmed.isNotEmpty ? trimmed : null,
    );
  }

  String toContentJson() {
    return jsonEncode({
      if (keyB64 != null) 'key': keyB64,
      'file_name': fileName,
      'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (caption != null && caption!.trim().isNotEmpty) 'caption': caption!.trim(),
    });
  }

  String get formattedFileSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      return fileName.substring(dotIdx + 1).toUpperCase();
    }
    return 'FILE';
  }
}
