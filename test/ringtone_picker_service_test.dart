import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/ringtone_picker_service.dart';

void main() {
  group('RingtonePickerService Models & Enum', () {
    test('RingtonePickResult correctly stores path, title, and uri', () {
      const result = RingtonePickResult(
        path: '/data/user/0/com.mekaar.mekaar_chat/files/custom_sounds/Bubble_1712345.m4a',
        title: 'Bubble',
        uri: 'content://media/internal/audio/media/42',
      );

      expect(result.path, '/data/user/0/com.mekaar.mekaar_chat/files/custom_sounds/Bubble_1712345.m4a');
      expect(result.title, 'Bubble');
      expect(result.uri, 'content://media/internal/audio/media/42');
      expect(result.toString(), contains('Bubble'));
    });

    test('RingtoneType enum values match Android intent mappings', () {
      expect(RingtoneType.notification.name, 'notification');
      expect(RingtoneType.ringtone.name, 'ringtone');
      expect(RingtoneType.alarm.name, 'alarm');
    });

    test('Custom sound name resolution strips timestamp suffix and path prefixes', () {
      String resolveCustomName(String path) {
        final fileName = path.split('/').last.split(r'\').last;
        final baseName = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        final cleanName = baseName.replaceAll(RegExp(r'_\d{10,}$'), '');
        return cleanName.isNotEmpty ? '$cleanName (Kustom)' : 'Nada Perangkat (Kustom)';
      }

      expect(
        resolveCustomName('/storage/emulated/0/Music/DJ_Beautiful_Things_1729267890123.mp3'),
        'DJ_Beautiful_Things (Kustom)',
      );
      expect(
        resolveCustomName(r'C:\Users\Sounds\Bottle.wav'),
        'Bottle (Kustom)',
      );
      expect(
        resolveCustomName('Bubble.ogg'),
        'Bubble (Kustom)',
      );
    });
  });
}
