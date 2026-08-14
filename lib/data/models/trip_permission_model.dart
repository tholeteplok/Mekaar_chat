class TripPermission {
  final String id;
  final String userId;
  final String guardianId;
  final String destinationName;
  final DateTime startTime;
  final DateTime endTime;
  final int pingIntervalMinutes;
  final bool reminder15mEnabled;
  final String status; // 'active', 'completed', 'cancelled_by_user'
  final double? lastLat;
  final double? lastLon;
  final DateTime? lastPingAt;
  final DateTime createdAt;

  TripPermission({
    required this.id,
    required this.userId,
    required this.guardianId,
    required this.destinationName,
    required this.startTime,
    required this.endTime,
    this.pingIntervalMinutes = 5,
    this.reminder15mEnabled = true,
    required this.status,
    this.lastLat,
    this.lastLon,
    this.lastPingAt,
    required this.createdAt,
  });

  bool get isActive => status == 'active' && DateTime.now().isBefore(endTime);

  factory TripPermission.fromMap(Map<String, dynamic> map) {
    return TripPermission(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      guardianId: map['guardian_id'] as String,
      destinationName: map['destination_name'] as String,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
      pingIntervalMinutes: map['ping_interval_minutes'] as int? ?? 5,
      reminder15mEnabled: map['reminder_15m_enabled'] as bool? ?? true,
      status: map['status'] as String? ?? 'active',
      lastLat: (map['last_lat'] as num?)?.toDouble(),
      lastLon: (map['last_lon'] as num?)?.toDouble(),
      lastPingAt: map['last_ping_at'] != null
          ? DateTime.parse(map['last_ping_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'guardian_id': guardianId,
      'destination_name': destinationName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'ping_interval_minutes': pingIntervalMinutes,
      'reminder_15m_enabled': reminder15mEnabled,
      'status': status,
      'last_lat': lastLat,
      'last_lon': lastLon,
      'last_ping_at': lastPingAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
