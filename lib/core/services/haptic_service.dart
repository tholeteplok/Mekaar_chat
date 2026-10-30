import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/notification_preferences.dart';

enum MekaarHapticIntent { selection, success, warning, destructive, emergency }

class HapticService {
  static bool? _enabledCache;
  static DateTime? _lastFeedbackAt;
  static const Duration _minimumInterval = Duration(milliseconds: 120);

  /// Dipanggil saat toggle diubah agar cache selalu sinkron.
  static void updateEnabled(bool value) => _enabledCache = value;

  @visibleForTesting
  static void resetForTest() {
    _enabledCache = null;
    _lastFeedbackAt = null;
  }

  static Future<bool> _isEnabled() async {
    final cached = _enabledCache;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    return _enabledCache =
        prefs.getBool(NotificationPreferences.hapticsEnabledKey) ?? true;
  }

  static Future<void> trigger(MekaarHapticIntent intent) async {
    if (!await _isEnabled() || !_canTrigger()) return;

    switch (intent) {
      case MekaarHapticIntent.selection:
        await HapticFeedback.selectionClick();
      case MekaarHapticIntent.success:
        await HapticFeedback.lightImpact();
      case MekaarHapticIntent.warning:
        await HapticFeedback.mediumImpact();
      case MekaarHapticIntent.destructive:
        await HapticFeedback.heavyImpact();
      case MekaarHapticIntent.emergency:
        await HapticFeedback.vibrate();
    }
  }

  static bool _canTrigger() {
    final now = DateTime.now();
    final previous = _lastFeedbackAt;
    if (previous != null && now.difference(previous) < _minimumInterval) {
      return false;
    }
    _lastFeedbackAt = now;
    return true;
  }
}
