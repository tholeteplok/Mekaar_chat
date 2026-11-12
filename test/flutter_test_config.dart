import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Konfigurasi global pengujian Flutter.
/// Otomatis dieksekusi sebelum setiap file tes di direktori test/ dijalankan.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1. Matikan runtime fetching GoogleFonts secara menyeluruh di seluruh test suite
  // untuk mencegah kebocoran HTTP dan FOUC di runner CI Linux.
  GoogleFonts.config.allowRuntimeFetching = false;

  // 2. Redam pesan sistem 'fontsChange' pada SystemChannels.system
  // agar RelayoutWhenSystemFontsChangeMixin di Flutter 3.50+ tidak menjadwalkan
  // transient frame callback yang tertinggal saat widget tree di-dispose.
  SystemChannels.system.setMessageHandler((dynamic message) async {
    return null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/system',
    (ByteData? message) async => ByteData(0),
  );

  await testMain();
}
