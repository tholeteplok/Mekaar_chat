enum MessageType { text, image, voice, video, system, location }

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String? mediaUrl;
  final MessageType type;
  final bool isViewOnce;
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

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.mediaUrl,
    required this.type,
    this.isViewOnce = false,
    this.replyToId,
    this.isDeleted = false,
    this.isSilentDeleted = false,
    this.isEncrypted = false,
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
          parsedReactions[key.toString()] =
              value.map((e) => e.toString()).toList();
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
    String? replyToId,
    bool? isDeleted,
    bool? isSilentDeleted,
    DateTime? autoDeleteAt,
    DateTime? editedAt,
    Map<String, List<String>>? reactions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEncrypted,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      type: type ?? this.type,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      isSilentDeleted: isSilentDeleted ?? this.isSilentDeleted,
      autoDeleteAt: autoDeleteAt ?? this.autoDeleteAt,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
