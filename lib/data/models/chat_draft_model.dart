class ChatDraft {
  final String roomId;
  final String content;
  final String? replyToId;
  final DateTime updatedAt;

  const ChatDraft({
    required this.roomId,
    required this.content,
    this.replyToId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'room_id': roomId,
    'content': content,
    'reply_to_id': replyToId,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory ChatDraft.fromMap(Map<String, dynamic> map) => ChatDraft(
    roomId: map['room_id'] as String,
    content: map['content'] as String,
    replyToId: map['reply_to_id'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at'] is int
          ? map['updated_at'] as int
          : int.tryParse(map['updated_at'].toString()) ?? 0,
    ),
  );

  ChatDraft copyWith({
    String? roomId,
    String? content,
    String? replyToId,
    DateTime? updatedAt,
  }) =>
      ChatDraft(
        roomId: roomId ?? this.roomId,
        content: content ?? this.content,
        replyToId: replyToId ?? this.replyToId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
