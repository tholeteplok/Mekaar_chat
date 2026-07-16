import 'package:flutter/material.dart';

class MekaarSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets dialog = EdgeInsets.fromLTRB(xl, lg, xl, md);
}

class MekaarRadius {
  static const double sm = 12;   // Chip, badge
  static const double md = 18;   // Bubble chat, input bar
  static const double lg = 24;   // Kartu chat list, sheet
  static const double xl = 32;   // Extra rounded
  static const double pill = 999; // Tombol, FAB, search bar, avatar
}

class MekaarSizes {
  static const double avatarMd = 38;
  static const double avatarLg = 48;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double fab = 60;  // FAB size to 60px (per design.md)
  static const double sos = 72;
  static const double composerButton = 42;
  static const double chatMediaWidth = 220;
  static const double chatMediaHeight = 180;
}
