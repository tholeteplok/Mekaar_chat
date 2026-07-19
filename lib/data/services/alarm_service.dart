import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';

import '../models/notification_preferences.dart';
import '../repositories/notification_preferences_repository.dart';

enum _ActiveAudio { none, call, sos }

class AlarmService {
  static final Logger _logger = Logger();
  static final AudioPlayer _callPlayer = AudioPlayer();
  static final AudioPlayer _sosPlayer = AudioPlayer();
  static final NotificationPreferencesRepository _preferencesRepository =
      NotificationPreferencesRepository();
  static _ActiveAudio _activeAudio = _ActiveAudio.none;

  static bool get isPlaying => _activeAudio != _ActiveAudio.none;
  static bool get isCallRingtonePlaying => _activeAudio == _ActiveAudio.call;
  static bool get isSosAlarmPlaying => _activeAudio == _ActiveAudio.sos;

  static Future<void> playMessageSound() async {
    if (_activeAudio != _ActiveAudio.none) return;

    AudioPlayer? player;
    try {
      final preferences = await _preferencesRepository.load();
      if (!preferences.messageSoundEnabled) return;

      player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.7);
      await player.play(
        _sourceFor(
          preferences.messageSound,
          NotificationPreferences.defaultMessageSound,
        ),
      );
      await player.onPlayerComplete.first;
    } catch (error) {
      _logger.e('AlarmService: Gagal memutar nada pesan: $error');
    } finally {
      await player?.dispose();
    }
  }

  static Future<void> startCallRingtone() async {
    if (_activeAudio == _ActiveAudio.call ||
        _activeAudio == _ActiveAudio.sos) {
      return;
    }

    try {
      final preferences = await _preferencesRepository.load();
      if (!preferences.callSoundEnabled) return;

      await _callPlayer.setReleaseMode(ReleaseMode.loop);
      await _callPlayer.setVolume(0.9);
      await _callPlayer.play(
        _sourceFor(
          preferences.callSound,
          NotificationPreferences.defaultCallSound,
        ),
      );
      _activeAudio = _ActiveAudio.call;
    } catch (error) {
      _logger.e('AlarmService: Gagal memutar ringtone panggilan: $error');
    }
  }

  static Future<void> stopCallRingtone() async {
    if (_activeAudio != _ActiveAudio.call) return;
    try {
      await _callPlayer.stop();
    } catch (error) {
      _logger.e('AlarmService: Gagal menghentikan ringtone: $error');
    } finally {
      _activeAudio = _ActiveAudio.none;
    }
  }

  static Future<void> playSOSAlarm() async {
    if (_activeAudio == _ActiveAudio.sos) return;
    await stopCallRingtone();

    try {
      final preferences = await _preferencesRepository.load();
      await _sosPlayer.setReleaseMode(ReleaseMode.loop);
      await _sosPlayer.setVolume(1);
      await _sosPlayer.play(
        _sourceFor(
          preferences.sosSound,
          NotificationPreferences.defaultSosSound,
        ),
      );
      _activeAudio = _ActiveAudio.sos;
    } catch (error) {
      _logger.e('AlarmService: Gagal memutar alarm SOS: $error');
    }
  }

  static Future<void> stopSOSAlarm() async {
    if (_activeAudio != _ActiveAudio.sos) return;
    try {
      await _sosPlayer.stop();
    } catch (error) {
      _logger.e('AlarmService: Gagal menghentikan alarm SOS: $error');
    } finally {
      _activeAudio = _ActiveAudio.none;
    }
  }

  static Future<void> stopAlarm() => stopSOSAlarm();

  static Source _sourceFor(String path, String fallback) {
    if (path.startsWith('sounds/')) return AssetSource(path);
    return File(path).existsSync()
        ? DeviceFileSource(path)
        : AssetSource(fallback);
  }
}
