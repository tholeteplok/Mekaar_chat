class ChatRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String invitationNote;
  final String status; // 'pending', 'accepted', 'rejected', 'blocked'
  final bool viaQrCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? senderUsername;
  final String? senderAvatarUrl;

  ChatRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.invitationNote,
    required this.status,
    this.viaQrCode = false,
    required this.createdAt,
    required this.updatedAt,
    this.senderUsername,
    this.senderAvatarUrl,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  factory ChatRequest.fromMap(Map<String, dynamic> map) {
    return ChatRequest(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      invitationNote: map['invitation_note'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      viaQrCode: map['via_qr_code'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      senderUsername: map['sender_profile']?['username'] as String?,
      senderAvatarUrl: map['sender_profile']?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'invitation_note': invitationNote,
      'status': status,
      'via_qr_code': viaQrCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
