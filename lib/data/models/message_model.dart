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
  final DateTime? autoDeleteAt;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.autoDeleteAt,
    required this.createdAt,
    required this.updatedAt,
  });

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
      autoDeleteAt: json['auto_delete_at'] != null
          ? DateTime.parse(json['auto_delete_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'auto_delete_at': autoDeleteAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    DateTime? autoDeleteAt,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      autoDeleteAt: autoDeleteAt ?? this.autoDeleteAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
