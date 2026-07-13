class Guardian {
  final String id;
  final String ownerId;
  final String guardianId;
  final String name; // Joined profile name / username
  final String email; // Joined profile email
  final Map<String, bool> permissions;
  final String storageOption; // 'stream_only' | 'save_server' | 'save_drive' | 'save_drive_temp'
  final String status; // 'pending' | 'active' | 'expired'
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Guardian({
    required this.id,
    required this.ownerId,
    required this.guardianId,
    required this.name,
    required this.email,
    required this.permissions,
    required this.storageOption,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get daysRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired {
    if (status == 'expired') return true;
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  factory Guardian.fromJson(Map<String, dynamic> json) {
    // Permissions parsing
    final rawPerms = json['permissions'] as Map<String, dynamic>? ?? {};
    final perms = <String, bool>{
      'gps': rawPerms['gps'] as bool? ?? false,
      'mic': rawPerms['mic'] as bool? ?? false,
      'video': rawPerms['video'] as bool? ?? false,
    };

    // Extract name and email from profile join if present, otherwise fallback
    String guardianName = 'User';
    String guardianEmail = '';
    
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      guardianName = profile['full_name'] as String? ?? profile['username'] as String? ?? 'User';
      guardianEmail = profile['email'] as String? ?? '';
    } else if (json['guardian_profile'] != null) {
      final profile = json['guardian_profile'] as Map<String, dynamic>;
      guardianName = profile['full_name'] as String? ?? profile['username'] as String? ?? 'User';
      guardianEmail = profile['email'] as String? ?? '';
    } else {
      guardianName = json['name'] as String? ?? 'User';
      guardianEmail = json['email'] as String? ?? '';
    }

    return Guardian(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      guardianId: json['guardian_id'] as String,
      name: guardianName,
      email: guardianEmail,
      permissions: perms,
      storageOption: json['storage_option'] as String? ?? 'stream_only',
      status: json['status'] as String? ?? 'pending',
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'guardian_id': guardianId,
      'permissions': permissions,
      'storage_option': storageOption,
      'status': status,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Guardian copyWith({
    String? id,
    String? ownerId,
    String? guardianId,
    String? name,
    String? email,
    Map<String, bool>? permissions,
    String? storageOption,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Guardian(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      guardianId: guardianId ?? this.guardianId,
      name: name ?? this.name,
      email: email ?? this.email,
      permissions: permissions ?? this.permissions,
      storageOption: storageOption ?? this.storageOption,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
