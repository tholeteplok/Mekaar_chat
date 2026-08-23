import 'package:flutter/widgets.dart';

/// Menandai subtree yang dipaksa gelap (SOS aktif / layar device-lost).
///
/// `MekaarScaffold` dengan `forceDark: true` hanya mengecat canvas,
/// sedangkan `ThemeData` global tetap mengikuti preferensi sistem.
/// Scope ini membuat helper warna adaptif (`MekaarColors.surfaceOf`,
/// `textPrimaryOf`, dst.) tetap meresolusi palet gelap di dalam subtree
/// tersebut, sehingga teks dan kartu tidak lagi putih-di-atas-gelap.
class ForceDarkScope extends InheritedWidget {
  final bool forceDark;

  const ForceDarkScope({
    super.key,
    required this.forceDark,
    required super.child,
  });

  /// True jika subtree saat ini dipaksa memakai palet gelap.
  static bool isForcedDark(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ForceDarkScope>()?.forceDark ??
      false;

  @override
  bool updateShouldNotify(ForceDarkScope oldWidget) =>
      oldWidget.forceDark != forceDark;
}
