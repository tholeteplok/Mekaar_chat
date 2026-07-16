import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const MekaarScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.forceDark = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget mainScaffold = Scaffold(
      backgroundColor: Colors.transparent, // Background handled by canvas gradient
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );

    if (forceDark) {
      mainScaffold = Theme(
        data: MekaarTheme.darkTheme(),
        child: mainScaffold,
      );
    }

    return MekaarCanvas(
      forceDark: forceDark,
      child: mainScaffold,
    );
  }
}
