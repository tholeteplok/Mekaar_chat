class RoomParticipantPreferences {
  final String roomId;
  final bool isMuted;
  final DateTime? mutedUntil;
  final int? disappearingOverrideHours;
  final bool isArchived;

  const RoomParticipantPreferences({
    required this.roomId,
    this.isMuted = false,
    this.mutedUntil,
    this.disappearingOverrideHours,
    this.isArchived = false,
  });

  factory RoomParticipantPreferences.fromJson(Map<String, dynamic> json) {
    return RoomParticipantPreferences(
      roomId: json['room_id'] as String? ?? '',
      isMuted: json['is_muted'] as bool? ?? false,
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'] as String)
          : null,
      disappearingOverrideHours: json['disappearing_override_hours'] as int?,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  RoomParticipantPreferences copyWith({
    String? roomId,
    bool? isMuted,
    DateTime? mutedUntil,
    int? disappearingOverrideHours,
    bool? isArchived,
    bool clearDisappearingOverride = false,
  }) {
    return RoomParticipantPreferences(
      roomId: roomId ?? this.roomId,
      isMuted: isMuted ?? this.isMuted,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      disappearingOverrideHours: clearDisappearingOverride
          ? null
          : (disappearingOverrideHours ?? this.disappearingOverrideHours),
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
