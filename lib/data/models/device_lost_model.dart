class DeviceLostState {
  final bool isLocked;
  final String lockMessage;
  final String? recoveryContact;
  final DateTime? lockedAt;

  const DeviceLostState({
    this.isLocked = false,
    this.lockMessage = 'Ponsel ini hilang. Harap hubungi nomor darurat di layar.',
    this.recoveryContact,
    this.lockedAt,
  });

  factory DeviceLostState.fromJson(Map<String, dynamic> json) {
    return DeviceLostState(
      isLocked: json['is_locked'] as bool? ?? false,
      lockMessage: json['lock_message'] as String? ??
          'Ponsel ini hilang. Harap hubungi nomor darurat di layar.',
      recoveryContact: json['recovery_contact'] as String?,
      lockedAt: json['locked_at'] != null
          ? DateTime.tryParse(json['locked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_locked': isLocked,
      'lock_message': lockMessage,
      'recovery_contact': recoveryContact,
      'locked_at': lockedAt?.toIso8601String(),
    };
  }

  DeviceLostState copyWith({
    bool? isLocked,
    String? lockMessage,
    String? recoveryContact,
    DateTime? lockedAt,
  }) {
    return DeviceLostState(
      isLocked: isLocked ?? this.isLocked,
      lockMessage: lockMessage ?? this.lockMessage,
      recoveryContact: recoveryContact ?? this.recoveryContact,
      lockedAt: lockedAt ?? this.lockedAt,
    );
  }
}
