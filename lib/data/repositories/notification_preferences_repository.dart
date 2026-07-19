import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';

class NotificationPreferencesRepository {
  Future<NotificationPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    await _migrateLegacyPreferences(preferences);

    return NotificationPreferences(
      messageSound: _validatedPath(
        preferences.getString(NotificationPreferences.messageSoundKey),
        NotificationPreferences.defaultMessageSound,
      ),
      callSound: _validatedPath(
        preferences.getString(NotificationPreferences.callSoundKey),
        NotificationPreferences.defaultCallSound,
      ),
      sosSound: _validatedPath(
        preferences.getString(NotificationPreferences.sosSoundKey),
        NotificationPreferences.defaultSosSound,
      ),
      messageSoundEnabled:
          preferences.getBool(NotificationPreferences.messageSoundEnabledKey) ??
          true,
      callSoundEnabled:
          preferences.getBool(NotificationPreferences.callSoundEnabledKey) ??
          true,
      hapticsEnabled:
          preferences.getBool(NotificationPreferences.hapticsEnabledKey) ?? true,
    );
  }

  Future<void> save(NotificationPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(
        NotificationPreferences.messageSoundKey,
        value.messageSound,
      ),
      preferences.setString(
        NotificationPreferences.callSoundKey,
        value.callSound,
      ),
      preferences.setString(
        NotificationPreferences.sosSoundKey,
        value.sosSound,
      ),
      preferences.setBool(
        NotificationPreferences.messageSoundEnabledKey,
        value.messageSoundEnabled,
      ),
      preferences.setBool(
        NotificationPreferences.callSoundEnabledKey,
        value.callSoundEnabled,
      ),
      preferences.setBool(
        NotificationPreferences.hapticsEnabledKey,
        value.hapticsEnabled,
      ),
    ]);
  }

  Future<void> _migrateLegacyPreferences(
    SharedPreferences preferences,
  ) async {
    if (preferences.containsKey(NotificationPreferences.messageSoundKey)) {
      return;
    }

    final legacy = preferences.getString(
      NotificationPreferences.legacyNormalSoundKey,
    );
    if (legacy != null && legacy.isNotEmpty) {
      await preferences.setString(
        NotificationPreferences.messageSoundKey,
        legacy,
      );
    }
  }

  String _validatedPath(String? path, String fallback) {
    if (path == null || path.isEmpty) return fallback;
    if (path.startsWith('sounds/')) return path;
    return File(path).existsSync() ? path : fallback;
  }
}
