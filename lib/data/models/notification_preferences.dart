class NotificationPreferences {
  static const String defaultMessageSound = 'system_default';
  static const String defaultCallSound = 'sounds/call_ringtone.wav';
  static const String defaultSosSound = 'sounds/sos_alarm.wav';
  static const String alternateSosSound = 'sounds/sos_scifi.wav';

  static const String messageSoundKey = 'ringtone_message_key';
  static const String groupMessageSoundKey = 'ringtone_group_message_key';
  static const String callSoundKey = 'ringtone_call_key';
  static const String sosSoundKey = 'ringtone_sos_key';
  static const String messageSoundEnabledKey = 'message_sound_enabled';
  static const String groupNotificationsEnabledKey = 'group_notifications_enabled';
  static const String callSoundEnabledKey = 'call_sound_enabled';
  static const String hapticsEnabledKey = 'haptics_enabled';
  static const String legacyNormalSoundKey = 'ringtone_normal_key';

  final String messageSound;
  final String groupMessageSound;
  final String callSound;
  final String sosSound;
  final bool messageSoundEnabled;
  final bool groupNotificationsEnabled;
  final bool callSoundEnabled;
  final bool hapticsEnabled;

  const NotificationPreferences({
    this.messageSound = defaultMessageSound,
    this.groupMessageSound = defaultMessageSound,
    this.callSound = defaultCallSound,
    this.sosSound = defaultSosSound,
    this.messageSoundEnabled = true,
    this.groupNotificationsEnabled = true,
    this.callSoundEnabled = true,
    this.hapticsEnabled = true,
  });

  NotificationPreferences copyWith({
    String? messageSound,
    String? groupMessageSound,
    String? callSound,
    String? sosSound,
    bool? messageSoundEnabled,
    bool? groupNotificationsEnabled,
    bool? callSoundEnabled,
    bool? hapticsEnabled,
  }) {
    return NotificationPreferences(
      messageSound: messageSound ?? this.messageSound,
      groupMessageSound: groupMessageSound ?? this.groupMessageSound,
      callSound: callSound ?? this.callSound,
      sosSound: sosSound ?? this.sosSound,
      messageSoundEnabled: messageSoundEnabled ?? this.messageSoundEnabled,
      groupNotificationsEnabled:
          groupNotificationsEnabled ?? this.groupNotificationsEnabled,
      callSoundEnabled: callSoundEnabled ?? this.callSoundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}
