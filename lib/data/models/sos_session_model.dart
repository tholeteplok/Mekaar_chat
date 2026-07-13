class SOSSession {
  final String id;
  final String userId;
  final String? guardianId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'active' | 'ended' | 'auto_ended'
  final bool gpsEnabled;
  final bool micEnabled;
  final bool videoEnabled;
  final String? endedReason; // 'manual' | 'timer' | 'inactivity'
  final DateTime createdAt;

  SOSSession({
    required this.id,
    required this.userId,
    this.guardianId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.gpsEnabled = true,
    this.micEnabled = false,
    this.videoEnabled = false,
    this.endedReason,
    required this.createdAt,
  });

  factory SOSSession.fromJson(Map<String, dynamic> json) {
    return SOSSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      guardianId: json['guardian_id'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      status: json['status'] as String? ?? 'active',
      gpsEnabled: json['gps_enabled'] as bool? ?? true,
      micEnabled: json['mic_enabled'] as bool? ?? false,
      videoEnabled: json['video_enabled'] as bool? ?? false,
      endedReason: json['ended_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'guardian_id': guardianId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'status': status,
      'gps_enabled': gpsEnabled,
      'mic_enabled': micEnabled,
      'video_enabled': videoEnabled,
      'ended_reason': endedReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SOSSession copyWith({
    String? id,
    String? userId,
    String? guardianId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? status,
    bool? gpsEnabled,
    bool? micEnabled,
    bool? videoEnabled,
    String? endedReason,
    DateTime? createdAt,
  }) {
    return SOSSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      guardianId: guardianId ?? this.guardianId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      micEnabled: micEnabled ?? this.micEnabled,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      endedReason: endedReason ?? this.endedReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
