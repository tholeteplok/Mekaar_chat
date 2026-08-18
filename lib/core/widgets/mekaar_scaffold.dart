import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sos/providers/sos_provider.dart';
import '../constants/theme_resolver.dart';
import '../constants/time_palette.dart';
import '../providers/theme_provider.dart';
import '../providers/time_tick_provider.dart';
import 'mekaar_canvas.dart';

class MekaarScaffold extends ConsumerWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final bool forceDark;
  final bool flat;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  const MekaarScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.forceDark = false,
    this.flat = true,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger rebuild per menit (untuk mode auto).
    ref.watch(timeTickProvider);

    final isSosActive = ref.watch(sosProvider).isSOSActive;

    final pref =
        ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.auto;
    final isDark = forceDark || isSosActive || ThemeResolver.isCurrentlyDark(pref);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    Widget mainScaffold = Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by canvas gradient
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
    );

    // forceDark honored untuk layar khusus (SOS / device-lost).
    // Catatan: ThemeData tidak di-overwrite karena sudah di-resolve di
    // MaterialApp level. Yang berubah hanya canvas (sudah di mekaar_canvas)
    // dan status bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MekaarCanvas(forceDark: forceDark, flat: flat, child: mainScaffold),
    );
  }
}
