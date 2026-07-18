class SecurityLog {
  final String id;
  final String userId;
  final String sosSessionId;
  final String eventType;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  const SecurityLog({
    required this.id,
    required this.userId,
    required this.sosSessionId,
    required this.eventType,
    this.details,
    required this.createdAt,
  });

  factory SecurityLog.fromJson(Map<String, dynamic> json) {
    return SecurityLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sosSessionId: json['sos_session_id'] as String,
      eventType: json['event_type'] as String,
      details: json['details'] == null
          ? null
          : Map<String, dynamic>.from(json['details'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'sos_session_id': sosSessionId,
    'event_type': eventType,
    'details': details,
    'created_at': createdAt.toIso8601String(),
  };
}
