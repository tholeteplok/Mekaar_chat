import 'package:flutter/material.dart';

class MekaarSpacing {
  static const double xxs = 2; // Celah mikro sub-grid (waveform, icon badge)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 32;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets dialog = EdgeInsets.fromLTRB(xl, lg, xl, md);
}

class MekaarRadius {
  static const double xxs = 2; // Bar waveform, garis progres mikro
  static const double xs = 4; // Progress bar, indikator status kecil
  static const double sm = 8; // Chip dalam gelembung, thumbnail balasan
  static const double sub = 10; // Overlay badge media, durasi voice
  static const double base = 12; // Chip, badge standar
  static const double card = 16; // Standar baku kartu Citrea (tetap & presisi)
  static const double md = 18; // Bubble chat, input bar
  static const double lg = 24; // Kartu chat list, sheet
  static const double xl = 32; // Extra rounded
  static const double pill = 999; // Tombol, FAB, search bar, avatar
}

class MekaarSizes {
  /// Target sentuh minimal WCAG 2.2 SC 2.5.8 & Material Design 3 (48x48 dp)
  static const double touchTargetMin = 48;
  static const double avatarMd = 38;
  static const double avatarLg = 48;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 24;
  /// Ukuran kontainer ikon standar pada tile/list (spec MekaarInfoTile).
  static const double iconBadge = 44;
  static const double fab = 60; // FAB size to 60px (per design.md)
  static const double sos = 72;
  static const double composerButton = 42;
  static const double chatMediaWidth = 220;
  static const double chatMediaHeight = 180;
}
