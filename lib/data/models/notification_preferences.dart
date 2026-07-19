class NotificationPreferences {
  static const String defaultMessageSound = 'sounds/normal_chime.mp3';
  static const String defaultCallSound = 'sounds/normal_playful.mp3';
  static const String defaultSosSound = 'sounds/sos_siren.mp3';

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
