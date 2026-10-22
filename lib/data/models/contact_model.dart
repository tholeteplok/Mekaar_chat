class ContactItem {
  final String id;
  final String contactUserId;
  final String username;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  final String? bio;
  final String? aliasName;
  final DateTime createdAt;
  final bool isGuardian;
  final bool isVaulted;
  final int vaultSlot;
  final String? roomId;

  const ContactItem({
    required this.id,
    required this.contactUserId,
    required this.username,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.bio,
    this.aliasName,
    required this.createdAt,
    this.isGuardian = false,
    this.isVaulted = false,
    this.vaultSlot = 1,
    this.roomId,
  });

  /// Nama prioritas untuk ditampilkan pada antarmuka:
  /// Alias lokal -> Display Name -> Full Name -> Username
  String get effectiveName {
    if (aliasName != null && aliasName!.trim().isNotEmpty) {
      return aliasName!.trim();
    }
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    return username.isNotEmpty ? username : 'Pengguna Mekaar';
  }

  factory ContactItem.fromJson(
    Map<String, dynamic> json, {
    bool isGuardian = false,
    String? roomId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>? ??
        json['public_profiles'] as Map<String, dynamic>? ??
        json;

    return ContactItem(
      id: json['id'] as String? ?? '',
      contactUserId: json['contact_user_id'] as String? ?? profile['id'] as String? ?? '',
      username: profile['username'] as String? ?? '',
      fullName: profile['full_name'] as String?,
      displayName: profile['display_name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      email: profile['email'] as String?,
      bio: profile['bio'] as String?,
      aliasName: json['alias_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isGuardian: isGuardian,
      isVaulted: json['is_vaulted'] as bool? ?? false,
      vaultSlot: (json['vault_slot'] as num?)?.toInt() ?? 1,
      roomId: roomId,
    );
  }

  ContactItem copyWith({
    String? id,
    String? contactUserId,
    String? username,
    String? fullName,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? bio,
    String? aliasName,
    DateTime? createdAt,
    bool? isGuardian,
    bool? isVaulted,
    int? vaultSlot,
    String? roomId,
  }) {
    return ContactItem(
      id: id ?? this.id,
      contactUserId: contactUserId ?? this.contactUserId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      aliasName: aliasName ?? this.aliasName,
      createdAt: createdAt ?? this.createdAt,
      isGuardian: isGuardian ?? this.isGuardian,
      isVaulted: isVaulted ?? this.isVaulted,
      vaultSlot: vaultSlot ?? this.vaultSlot,
      roomId: roomId ?? this.roomId,
    );
  }
}
