/// Model data perangkat terdaftar (user_devices).
///
/// Setiap instalasi aplikasi MEKAAR mendapat baris unik di tabel `user_devices`,
/// memungkinkan push notification dan remote command ditargetkan ke perangkat spesifik.
class UserDevice {
  final String id;
  final String profileId;
  final String deviceId;
  final String? fcmToken;
  final String? deviceLabel;
  final String platform;
  final String? appVersion;
  final DateTime lastSeenAt;
  final DateTime createdAt;

  const UserDevice({
    required this.id,
    required this.profileId,
    required this.deviceId,
    this.fcmToken,
    this.deviceLabel,
    required this.platform,
    this.appVersion,
    required this.lastSeenAt,
    required this.createdAt,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      deviceId: json['device_id'] as String,
      fcmToken: json['fcm_token'] as String?,
      deviceLabel: json['device_label'] as String?,
      platform: json['platform'] as String? ?? 'unknown',
      appVersion: json['app_version'] as String?,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'device_id': deviceId,
        'fcm_token': fcmToken,
        'device_label': deviceLabel,
        'platform': platform,
        'app_version': appVersion,
        'last_seen_at': lastSeenAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  /// Apakah device ini adalah perangkat yang sedang aktif saat ini
  /// (dibandingkan oleh layer consumer, bukan di model sendiri).
  bool isCurrent(String currentDeviceId) => deviceId == currentDeviceId;
}
