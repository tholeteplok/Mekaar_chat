class NotificationPreferences {
  static const String defaultMessageSound = 'sounds/msg_confirmation.wav';
  static const String alternateMessageSound = 'sounds/msg_pop.wav';
  static const String defaultCallSound = 'sounds/call_ringtone.wav';
  static const String alternateCallSound = 'sounds/msg_confirmation.wav';
  static const String defaultSosSound = 'sounds/sos_alarm.wav';
  static const String alternateSosSound = 'sounds/sos_scifi.wav';

  static const String messageSoundKey = 'ringtone_message_key';
  static const String callSoundKey = 'ringtone_call_key';
  static const String sosSoundKey = 'ringtone_sos_key';
  static const String messageSoundEnabledKey = 'message_sound_enabled';
  static const String callSoundEnabledKey = 'call_sound_enabled';
  static const String hapticsEnabledKey = 'haptics_enabled';
  static const String legacyNormalSoundKey = 'ringtone_normal_key';

  final String messageSound;
  final String callSound;
  final String sosSound;
  final bool messageSoundEnabled;
  final bool callSoundEnabled;
  final bool hapticsEnabled;

  const NotificationPreferences({
    this.messageSound = defaultMessageSound,
    this.callSound = defaultCallSound,
    this.sosSound = defaultSosSound,
    this.messageSoundEnabled = true,
    this.callSoundEnabled = true,
    this.hapticsEnabled = true,
  });

  NotificationPreferences copyWith({
    String? messageSound,
    String? callSound,
    String? sosSound,
    bool? messageSoundEnabled,
    bool? callSoundEnabled,
    bool? hapticsEnabled,
  }) {
    return NotificationPreferences(
      messageSound: messageSound ?? this.messageSound,
      callSound: callSound ?? this.callSound,
      sosSound: sosSound ?? this.sosSound,
      messageSoundEnabled: messageSoundEnabled ?? this.messageSoundEnabled,
      callSoundEnabled: callSoundEnabled ?? this.callSoundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}
