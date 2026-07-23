import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sos/providers/sos_provider.dart';
import '../constants/themes.dart';
import 'mekaar_canvas.dart';

class MekaarScaffold extends ConsumerWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final bool forceDark;
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
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSosActive = ref.watch(sosProvider).isSOSActive;
    final useLightIcons =
        forceDark ||
        isSosActive ||
        Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: useLightIcons
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: useLightIcons ? Brightness.dark : Brightness.light,
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

    if (forceDark) {
      mainScaffold = Theme(data: MekaarTheme.darkTheme(), child: mainScaffold);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MekaarCanvas(forceDark: forceDark, child: mainScaffold),
    );
  }
}
