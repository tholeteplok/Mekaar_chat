import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Konfigurasi global pengujian Flutter.
/// Otomatis dieksekusi sebelum setiap file tes di direktori test/ dijalankan.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Matikan runtime fetching GoogleFonts secara menyeluruh di seluruh test suite
  // untuk mencegah kebocoran HTTP, FOUC, dan transient callback relayout font di runner CI Linux.
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
