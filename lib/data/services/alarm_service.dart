import 'dart:async';
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
  static Timer? _sosTimeoutTimer;

  static bool get isPlaying => _activeAudio != _ActiveAudio.none;
  static bool get isCallRingtonePlaying => _activeAudio == _ActiveAudio.call;
  static bool get isSosAlarmPlaying => _activeAudio == _ActiveAudio.sos;

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

  static Future<void> playSOSAlarm({
    Duration autoStopTimeout = const Duration(minutes: 3),
  }) async {
    if (_activeAudio == _ActiveAudio.sos) return;
    await stopCallRingtone();

    try {
      _sosTimeoutTimer?.cancel();

      // Konfigurasi AudioContext hardware alarm stream untuk menembus mode Silent / Do Not Disturb
      await _sosPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );

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

      // Safety timeout: auto-stop alarm setelah periode tertentu agar baterai perangkat tidak terkuras
      _sosTimeoutTimer = Timer(autoStopTimeout, () {
        _logger.i(
          'AlarmService: Auto-stop alarm SOS dipicu setelah ${autoStopTimeout.inMinutes} menit demi keamanan baterai.',
        );
        stopSOSAlarm();
      });
    } catch (error) {
      _logger.e('AlarmService: Gagal memutar alarm SOS: $error');
    }
  }

  static Future<void> stopSOSAlarm() async {
    _sosTimeoutTimer?.cancel();
    _sosTimeoutTimer = null;
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
    if (path.startsWith('content://') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return UrlSource(path);
    }
    return File(path).existsSync()
        ? DeviceFileSource(path)
        : AssetSource(fallback);
  }
}
