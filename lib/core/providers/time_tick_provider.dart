import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream ticker setiap 1 menit untuk memicu rebuild widget ketika
/// mode tema = Otomatis dan slot waktu berganti. Ringan untuk baterai
/// (1 event/menit) dan cukup akurat untuk transisi slot 4-jam-an.
///
/// Timer & StreamController di-cancel pada dispose supaya tidak
/// menggantung di test ("Timer is still pending").
final timeTickProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  // Emit value pertama segera agar widget initial-build tahu waktu.
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (!controller.isClosed) controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
