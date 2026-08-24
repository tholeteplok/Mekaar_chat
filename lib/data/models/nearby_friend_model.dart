enum NearbyBand {
  veryClose, // < 500m
  close, // 500m - 2km
  sameCity; // 2km - 10km

  String get label {
    switch (this) {
      case NearbyBand.veryClose:
        return 'Sangat dekat (< 500 m)';
      case NearbyBand.close:
        return 'Dekat (500 m – 2 km)';
      case NearbyBand.sameCity:
        return 'Di kota yang sama';
    }
  }

  String get shortLabel {
    switch (this) {
      case NearbyBand.veryClose:
        return '< 500 m';
      case NearbyBand.close:
        return 'Dekat';
      case NearbyBand.sameCity:
        return 'Satu Kota';
    }
  }

  double get avatarSize {
    switch (this) {
      case NearbyBand.veryClose:
        return 68.0;
      case NearbyBand.close:
        return 54.0;
      case NearbyBand.sameCity:
        return 42.0;
    }
  }

  static NearbyBand fromString(String? value) {
    switch (value) {
      case 'very_close':
        return NearbyBand.veryClose;
      case 'close':
        return NearbyBand.close;
      case 'same_city':
      default:
        return NearbyBand.sameCity;
    }
  }

  String toDbString() {
    switch (this) {
      case NearbyBand.veryClose:
        return 'very_close';
      case NearbyBand.close:
        return 'close';
      case NearbyBand.sameCity:
        return 'same_city';
    }
  }
}

class NearbyFriendModel {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final NearbyBand band;
  final bool isRecent;
  final bool isContact;
  final String chatInvitationMode;

  const NearbyFriendModel({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.band,
    required this.isRecent,
    required this.isContact,
    this.chatInvitationMode = 'approved_only',
  });

  factory NearbyFriendModel.fromJson(Map<String, dynamic> json) {
    return NearbyFriendModel(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Pengguna MEKAAR',
      avatarUrl: json['avatar_url'] as String?,
      band: NearbyBand.fromString(json['band'] as String?),
      isRecent: json['is_recent'] as bool? ?? true,
      isContact: json['is_contact'] as bool? ?? false,
      chatInvitationMode: json['chat_invitation_mode'] as String? ?? 'approved_only',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'band': band.toDbString(),
      'is_recent': isRecent,
      'is_contact': isContact,
      'chat_invitation_mode': chatInvitationMode,
    };
  }

  NearbyFriendModel copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    NearbyBand? band,
    bool? isRecent,
    bool? isContact,
    String? chatInvitationMode,
  }) {
    return NearbyFriendModel(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      band: band ?? this.band,
      isRecent: isRecent ?? this.isRecent,
      isContact: isContact ?? this.isContact,
      chatInvitationMode: chatInvitationMode ?? this.chatInvitationMode,
    );
  }
}

class NearbyPreferences {
  final bool enabled;
  final String visibilityMode; // 'contacts_only' or 'everyone'
  final DateTime? updatedAt;

  const NearbyPreferences({
    this.enabled = false,
    this.visibilityMode = 'contacts_only',
    this.updatedAt,
  });

  factory NearbyPreferences.fromJson(Map<String, dynamic> json) {
    return NearbyPreferences(
      enabled: json['enabled'] as bool? ?? false,
      visibilityMode: json['visibility_mode'] as String? ?? 'contacts_only',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'visibility_mode': visibilityMode,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
