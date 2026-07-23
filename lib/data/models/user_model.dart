enum LastSeenPrivacy {
  everyone('everyone', 'Semua orang'),
  contacts('contacts', 'Kontak saya'),
  nobody('nobody', 'Tidak ada');

  final String value;
  final String label;
  const LastSeenPrivacy(this.value, this.label);

  static LastSeenPrivacy fromValue(String? value) {
    return LastSeenPrivacy.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LastSeenPrivacy.everyone,
    );
  }
}

class Profile {
  final String id;
  final String username;
  final String email;
  final String pinHash;
  final DateTime? pinLockedUntil;
  final String? duressPinHash;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LastSeenPrivacy lastSeenPrivacy;
  final bool readReceiptsEnabled;
  final int autoDeleteDefaultHours;
  final bool twoFaEnabled;
  final String? twoFaSecret;
  final String? lastLoginDevice;
  final DateTime? lastLoginAt;

  Profile({
    required this.id,
    required this.username,
    required this.email,
    required this.pinHash,
    this.pinLockedUntil,
    this.duressPinHash,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastSeenPrivacy = LastSeenPrivacy.everyone,
    this.readReceiptsEnabled = true,
    this.autoDeleteDefaultHours = 0,
    this.twoFaEnabled = false,
    this.twoFaSecret,
    this.lastLoginDevice,
    this.lastLoginAt,
  });

  bool get hasUsername => username.trim().isNotEmpty;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      email: json['email'] as String,
      pinHash: json['pin_hash'] as String? ?? '',
      pinLockedUntil: json['pin_locked_until'] != null
          ? DateTime.parse(json['pin_locked_until'] as String)
          : null,
      duressPinHash: json['duress_pin_hash'] as String?,
      fullName: json['full_name'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastSeenPrivacy:
          LastSeenPrivacy.fromValue(json['last_seen_privacy'] as String?),
      readReceiptsEnabled: json['read_receipts_enabled'] as bool? ?? true,
      autoDeleteDefaultHours: json['auto_delete_default_hours'] as int? ?? 0,
      twoFaEnabled: json['two_fa_enabled'] as bool? ?? false,
      twoFaSecret: json['two_fa_secret'] as String?,
      lastLoginDevice: json['last_login_device'] as String?,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
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
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_seen_privacy': lastSeenPrivacy.value,
      'read_receipts_enabled': readReceiptsEnabled,
      'auto_delete_default_hours': autoDeleteDefaultHours,
      'two_fa_enabled': twoFaEnabled,
      'two_fa_secret': twoFaSecret,
      'last_login_device': lastLoginDevice,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? email,
    String? pinHash,
    DateTime? pinLockedUntil,
    String? fullName,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    LastSeenPrivacy? lastSeenPrivacy,
    bool? readReceiptsEnabled,
    int? autoDeleteDefaultHours,
    bool? twoFaEnabled,
    String? twoFaSecret,
    String? lastLoginDevice,
    DateTime? lastLoginAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      pinHash: pinHash ?? this.pinHash,
      pinLockedUntil: pinLockedUntil ?? this.pinLockedUntil,
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenPrivacy: lastSeenPrivacy ?? this.lastSeenPrivacy,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      autoDeleteDefaultHours:
          autoDeleteDefaultHours ?? this.autoDeleteDefaultHours,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      twoFaSecret: twoFaSecret ?? this.twoFaSecret,
      lastLoginDevice: lastLoginDevice ?? this.lastLoginDevice,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
