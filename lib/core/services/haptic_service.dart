import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/notification_preferences.dart';

enum MekaarHapticIntent {
  selection,
  success,
  warning,
  destructive,
  emergency,
}

class HapticService {
  static DateTime? _lastFeedbackAt;
  static const Duration _minimumInterval = Duration(milliseconds: 120);

  static Future<void> trigger(MekaarHapticIntent intent) async {
    final preferences = await SharedPreferences.getInstance();
    final enabled =
        preferences.getBool(NotificationPreferences.hapticsEnabledKey) ?? true;
    if (!enabled || !_canTrigger()) return;

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
