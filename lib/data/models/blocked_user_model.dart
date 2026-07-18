class BlockedUser {
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;

  BlockedUser({
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
