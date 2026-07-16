class Profile {
  final String id;
  final String username;
  final String email;
  final String pinHash;
  final DateTime? pinLockedUntil;
  final String? duressPinHash;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.username,
    required this.email,
    required this.pinHash,
    this.pinLockedUntil,
    this.duressPinHash,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      pinHash: json['pin_hash'] as String? ?? '',
      pinLockedUntil: json['pin_locked_until'] != null
          ? DateTime.parse(json['pin_locked_until'] as String)
          : null,
      duressPinHash: json['duress_pin_hash'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'pin_hash': pinHash,
      'pin_locked_until': pinLockedUntil?.toIso8601String(),
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? email,
    String? pinHash,
    DateTime? pinLockedUntil,
    String? fullName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      pinHash: pinHash ?? this.pinHash,
      pinLockedUntil: pinLockedUntil ?? this.pinLockedUntil,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
