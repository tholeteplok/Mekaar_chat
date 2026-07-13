class SecurityLog {
  final String id;
  final String userId;
  final String eventType; // 'sos_started', 'sos_ended', 'guardian_gps_access', etc.
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final DateTime? deletedAt; // Soft delete timestamp

  SecurityLog({
    required this.id,
    required this.userId,
    required this.eventType,
    this.details,
    required this.createdAt,
    this.deletedAt,
  });

  factory SecurityLog.fromJson(Map<String, dynamic> json) {
    return SecurityLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventType: json['event_type'] as String,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'details': details,
      'created_at': createdAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  SecurityLog copyWith({
    String? id,
    String? userId,
    String? eventType,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    DateTime? deceasedAt,
  }) {
    return SecurityLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deceasedAt ?? deletedAt,
    );
  }
}
