import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tidak ada HapticFeedback mentah di luar HapticService', () {
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart')) {
        continue;
      }
      if (path.endsWith('core/services/haptic_service.dart')) {
        continue;
      }
      if (path.contains('lib/src/rust')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('HapticFeedback.')) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Pakai HapticService.trigger:\n${offenders.join('\n')}',
    );
  });

  group('HapticService', () {
    final calls = <String>[];

    setUp(() {
      calls.clear();
      HapticService.resetForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments?.toString() ?? 'vibrate');
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('tidak bergetar saat toggle dimatikan', () async {
      SharedPreferences.setMockInitialValues({'haptics_enabled': false});
      await HapticService.trigger(MekaarHapticIntent.success);
      expect(calls, isEmpty);
    });

    test('updateEnabled(false) langsung berlaku tanpa membaca prefs lagi', () async {
      SharedPreferences.setMockInitialValues({});
      await HapticService.trigger(MekaarHapticIntent.selection);
      expect(calls, isNotEmpty);

      calls.clear();
      HapticService.resetForTest(); // hindari throttle 120 ms antar-tes
      HapticService.updateEnabled(false);
      await HapticService.trigger(MekaarHapticIntent.selection);
      expect(calls, isEmpty);
    });

    test(
      'updateEnabled(true) mengaktifkan getaran dan memetakan intent dengan benar',
      () async {
        SharedPreferences.setMockInitialValues({'haptics_enabled': false});
        HapticService.updateEnabled(true);
        await HapticService.trigger(MekaarHapticIntent.destructive);
        expect(calls, contains('HapticFeedbackType.heavyImpact'));
      },
    );
  });
}
