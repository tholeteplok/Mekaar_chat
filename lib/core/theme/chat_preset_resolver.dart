import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/chat_theme_model.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';

/// Tipe animasi masuk signature per preset tema.
enum EntranceType {
  neumorphismSoft,
  glassmorphismBlur,
  pixelGlitchStep,
  isometricSnap,
  retroY2KHeaderFirst,
  swissRevealHorizontal,
  solarpunkGrowth,
  neonFlickerGlow,
  comicPopElastic,
  mekaarFadeSlide,
  dynamicTimeFadeSlide,
  fireflySlowGlow,
  diaryWritingSlideLeft,
  mechaTacticalSnap,
}

/// Spec animasi masuk gelembung pesan per preset tema.
class BubbleEntranceSpec {
  final Duration duration;
  final Curve curve;
  final EntranceType type;

  const BubbleEntranceSpec({
    required this.duration,
    required this.curve,
    required this.type,
  });
}

/// Spec styling lengkap untuk gelembung chat (termasuk Tipografi).
class ChatBubbleSpec {
  final Color backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;
  final Color textColor;
  final String? fontFamily;
  final TextStyle textStyle;
  final Widget? headerWidget;

  const ChatBubbleSpec({
    required this.backgroundColor,
    this.gradient,
    this.border,
    required this.borderRadius,
    this.boxShadow,
    required this.textColor,
    this.fontFamily,
    required this.textStyle,
    this.headerWidget,
  });
}

/// Spec styling lengkap untuk seluruh komponen UI Chat Room (AppBar, Composer, Buttons, Dividers, Badges).
class ChatRoomThemeSpec {
  final Color primaryAccentColor;
  final Color secondaryAccentColor;
  final Color iconColor;
  final Color textColor;
  final Color subtitleColor;
  final Border? glassBorder;
  final Color? glassBackgroundColor;

  const ChatRoomThemeSpec({
    required this.primaryAccentColor,
    required this.secondaryAccentColor,
    required this.iconColor,
    required this.textColor,
    required this.subtitleColor,
    this.glassBorder,
    this.glassBackgroundColor,
  });
}

/// Resolver tersentralisasi untuk 7 Preset Tema Chat Mekaar (Adaptif Light & Dark).
class ChatPresetResolver {
  ChatPresetResolver._();

  /// Mendapatkan spesifikasi animasi masuk signature untuk preset tema yang dipilih.
  static BubbleEntranceSpec getEntranceAnimation(ChatThemePreset preset) {
    switch (preset) {
      case ChatThemePreset.neuro:
      case ChatThemePreset.neumorphism:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          type: EntranceType.neumorphismSoft,
        );
      case ChatThemePreset.mecha:
      case ChatThemePreset.glass:
      case ChatThemePreset.glassmorphism:
      case ChatThemePreset.fireflyNight:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          type: EntranceType.mechaTacticalSnap,
        );
      case ChatThemePreset.pixel:
      case ChatThemePreset.pixelGarden:
      case ChatThemePreset.retroWave:
      case ChatThemePreset.retroY2K:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOut,
          type: EntranceType.pixelGlitchStep,
        );
      case ChatThemePreset.candy:
      case ChatThemePreset.candyPop:
      case ChatThemePreset.isometric3d:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.elasticOut,
          type: EntranceType.comicPopElastic,
        );
      case ChatThemePreset.comic:
      case ChatThemePreset.comicPopArt:
      case ChatThemePreset.diary:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.elasticOut,
          type: EntranceType.comicPopElastic,
        );
      case ChatThemePreset.eco:
      case ChatThemePreset.solarpunk:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          type: EntranceType.solarpunkGrowth,
        );
      case ChatThemePreset.neonDreams:
      case ChatThemePreset.neonCyberpunk:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
          type: EntranceType.neonFlickerGlow,
        );
      case ChatThemePreset.monoVibe:
      case ChatThemePreset.swissMinimalist:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeInOutQuart,
          type: EntranceType.swissRevealHorizontal,
        );
      case ChatThemePreset.mekaar:
      case ChatThemePreset.dynamicTime:
      case ChatThemePreset.custom:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          type: EntranceType.mekaarFadeSlide,
        );
    }
  }

  /// Mendapatkan spesifikasi visual gelembung obrolan berdasarkan preferensi & posisi (pengirim/penerima).
  static ChatBubbleSpec getBubbleSpec(
    ChatThemePreference pref,
    BuildContext context, {
    required bool isMe,
    double baseFontSize = 16.0,
    String? fontFamily,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = baseFontSize * pref.textScale;
    final activeFont = (fontFamily != null && fontFamily.isNotEmpty)
        ? fontFamily
        : MekaarTypography.fontFamily;

    // Helper untuk meresolusi TextStyle sesuai Preset Font
    TextStyle resolveTextStyle(Color textColor) {
      try {
        switch (pref.preset) {
          case ChatThemePreset.comic:
          case ChatThemePreset.comicPopArt:
          case ChatThemePreset.diary:
            return GoogleFonts.comicNeue(
              color: textColor,
              fontSize: fontSize + 1,
              height: 1.3,
              fontWeight: FontWeight.w700,
            );
          case ChatThemePreset.neuro:
          case ChatThemePreset.neumorphism:
            return GoogleFonts.getFont(
              activeFont,
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              fontWeight: FontWeight.w500,
            );
          case ChatThemePreset.mecha:
          case ChatThemePreset.glass:
          case ChatThemePreset.glassmorphism:
          case ChatThemePreset.fireflyNight:
            return GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.pixel:
          case ChatThemePreset.pixelGarden:
          case ChatThemePreset.retroWave:
          case ChatThemePreset.retroY2K:
            return GoogleFonts.dotGothic16(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.candy:
          case ChatThemePreset.candyPop:
          case ChatThemePreset.isometric3d:
            return GoogleFonts.fredoka(
              color: textColor,
              fontSize: fontSize,
              height: 1.3,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.eco:
          case ChatThemePreset.solarpunk:
            return GoogleFonts.comfortaa(
              color: textColor,
              fontSize: fontSize - 1,
              height: 1.4,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.neonDreams:
          case ChatThemePreset.neonCyberpunk:
          case ChatThemePreset.monoVibe:
          case ChatThemePreset.swissMinimalist:
            return GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w700,
            );
          case ChatThemePreset.mekaar:
          case ChatThemePreset.dynamicTime:
          case ChatThemePreset.custom:
            return GoogleFonts.getFont(
              activeFont,
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
            );
        }
      } catch (_) {
        return TextStyle(
          fontFamily: activeFont,
          color: textColor,
          fontSize: fontSize,
          height: 1.4,
        );
      }
    }

    // Helper parsing Hex Color
    Color? parseHexColor(String? hex) {
      if (hex == null || hex.isEmpty) return null;
      try {
        final cleaned = hex.replaceAll('#', '').trim();
        final val = int.parse(cleaned, radix: 16);
        return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
      } catch (_) {
        return null;
      }
    }

    // 0. Custom Bubble Color Override (with 2-Color Gradient Support & Auto Contrast)
    if (pref.useCustomBubbleColors) {
      final hex1 = isMe ? pref.outgoingColor1 : pref.incomingColor1;
      final hex2 = isMe ? pref.outgoingColor2 : pref.incomingColor2;
      final color1 = parseHexColor(hex1);
      final color2 = parseHexColor(hex2);

      if (color1 != null) {
        final gradient = color2 != null
            ? LinearGradient(
                colors: [color1, color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null;

        final txtColor = color1.computeLuminance() < 0.45
            ? Colors.white
            : const Color(0xFF1A1A1A);

        return ChatBubbleSpec(
          backgroundColor: color1,
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color1.withValues(alpha: isDark ? 0.3 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          textColor: txtColor,
          fontFamily: activeFont,
          textStyle: resolveTextStyle(txtColor),
        );
      }
    }

    // 1. Comic Pop Art
    if (pref.preset == ChatThemePreset.comic ||
        pref.preset == ChatThemePreset.comicPopArt ||
        pref.preset == ChatThemePreset.diary ||
        pref.bubbleStyle == ChatBubbleStyle.playfulOutlined) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.black;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFEAB308), // Classic Yellow Gold Comic
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFFDF4FF);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF2B1D3D), // Neo-noir purple
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
        const txt = Colors.black;
        return ChatBubbleSpec(
          backgroundColor: isMe ? const Color(0xFF38BDF8) : Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3)),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 2. Neuro / Neumorphism Soft UI
    if (pref.preset == ChatThemePreset.neuro ||
        pref.preset == ChatThemePreset.neumorphism ||
        pref.bubbleStyle == ChatBubbleStyle.neumorphicSoft) {
      if (isDark) {
        if (isMe) {
          const txt = Color(0xFF67E8F9);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF2B3342),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF191D24),
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFE2E8F0);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF242933),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF191D24),
                offset: Offset(3, 3),
                blurRadius: 6,
              ),
              BoxShadow(
                color: Color(0xFF2F3542),
                offset: Offset(-2, -2),
                blurRadius: 6,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
        if (isMe) {
          const txt = Color(0xFF0369A1);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFD8E2EC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFCBD5E1),
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFF1E293B);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFC8D0DA),
                offset: Offset(3, 3),
                blurRadius: 6,
              ),
              BoxShadow(
                color: Color(0xFFFCFFFF),
                offset: Offset(-3, -3),
                blurRadius: 6,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      }
    }

    // 3. Mecha Style (Tactical Armor & Cyber Grid — Menggantikan Glassmorphism)
    if (pref.preset == ChatThemePreset.mecha ||
        pref.preset == ChatThemePreset.glass ||
        pref.preset == ChatThemePreset.glassmorphism ||
        pref.preset == ChatThemePreset.fireflyNight ||
        pref.bubbleStyle == ChatBubbleStyle.mechaChamfer ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      if (isDark) {
        if (isMe) {
          const txt = Color(0xFFE6FFFA);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF004E5A),
            border: const Border(right: BorderSide(color: Color(0xFF00F0FF), width: 3.5)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(2),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3500F0FF),
                blurRadius: 10,
                offset: Offset(0, 0),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFE0F2FE);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF112233),
            border: const Border(left: BorderSide(color: Color(0xFF00F0FF), width: 3.5)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2500F0FF),
                blurRadius: 10,
                offset: Offset(0, 0),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
        if (isMe) {
          const txt = Color(0xFF0369A1);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFDBEAFE),
            border: const Border(right: BorderSide(color: Color(0xFF0284C7), width: 3.5)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(2),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0284C7),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFF0F172A);
          return ChatBubbleSpec(
            backgroundColor: Colors.white,
            border: const Border(left: BorderSide(color: Color(0xFF0284C7), width: 3.5)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      }
    }

    // 4. Pixel Garden / Craft 8-Bit (Minecraft Voxel)
    if (pref.preset == ChatThemePreset.pixel ||
        pref.preset == ChatThemePreset.pixelGarden ||
        pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF5B8731), // Grass Block Green
            border: Border.all(color: const Color(0xFF2D4514), width: 2.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
            headerWidget: _buildPixelHeader(isMe: true, isDark: true),
          );
        } else {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF484848), // Deepslate Stone
            border: Border.all(color: const Color(0xFF1E1E1E), width: 2.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
            headerWidget: _buildPixelHeader(isMe: false, isDark: true),
          );
        }
      } else {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF5B8731), // Grass Block Green
            border: Border.all(color: const Color(0xFF2D4514), width: 2.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF1B2D0B),
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
            headerWidget: _buildPixelHeader(isMe: true, isDark: false),
          );
        } else {
          const txt = Color(0xFF2E1E0A);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFC6B287), // Oak Wood Planks
            border: Border.all(color: const Color(0xFF8C734B), width: 2.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF4A2E12),
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
            headerWidget: _buildPixelHeader(isMe: false, isDark: false),
          );
        }
      }
    }

    // 5. Candy Pop (Playful)
    if (pref.preset == ChatThemePreset.candy ||
        pref.preset == ChatThemePreset.candyPop ||
        pref.preset == ChatThemePreset.isometric3d ||
        pref.bubbleStyle == ChatBubbleStyle.classicRounded ||
        pref.bubbleStyle == ChatBubbleStyle.isometric3D) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFDB2777),
            gradient: const LinearGradient(
              colors: [Color(0xFFDB2777), Color(0xFFE11D48)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40DB2777),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFFCE7F3);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF381E35), // Sweet Berry Blackcurrant
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFF472B6),
            gradient: const LinearGradient(
              colors: [Color(0xFFF472B6), Color(0xFFFB7185)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35FB7185),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFF831843);
          return ChatBubbleSpec(
            backgroundColor: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x25F472B6),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      }
    }

    // 6. Eco / Solarpunk (Calm Nature Kit)
    if (pref.preset == ChatThemePreset.eco ||
        pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      if (isDark) {
        if (isMe) {
          const txt = Color(0xFFF4EFE8);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF344837), // Muted Moss
            border: Border.all(color: const Color(0xFF4A634E), width: 1.0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFE8EFE8);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF202D23), // Forest Earth
            border: Border.all(color: const Color(0xFF2F4233), width: 1.0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
        if (isMe) {
          const txt = Color(0xFFF4EFE8);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF6B7F6E), // Sage Green
            border: Border.all(color: const Color(0xFF5A6D5D), width: 1.0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x286B7F6E),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFF2D3A2F);
          return ChatBubbleSpec(
            backgroundColor: Colors.white,
            border: Border.all(color: const Color(0xFFD9E1D9), width: 1.0), // Mist border
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x146B7F6E),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      }
    }

    // 7. MEKAAR Core Theme (Default Fallback)
    if (isDark) {
      if (isMe) {
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF0284C7),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x400284C7),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          textColor: Colors.white,
          fontFamily: activeFont,
          textStyle: resolveTextStyle(Colors.white),
        );
      } else {
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFF334155), width: 1.0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          textColor: const Color(0xFFF1F5F9),
          fontFamily: activeFont,
          textStyle: resolveTextStyle(const Color(0xFFF1F5F9)),
        );
      }
    } else {
      if (isMe) {
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF0284C7),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x300284C7),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
          textColor: Colors.white,
          fontFamily: activeFont,
          textStyle: resolveTextStyle(Colors.white),
        );
      } else {
        return ChatBubbleSpec(
          backgroundColor: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
          textColor: const Color(0xFF0F172A),
          fontFamily: activeFont,
          textStyle: resolveTextStyle(const Color(0xFF0F172A)),
        );
      }
    }
  }

  /// Mendapatkan spesifikasi tema tersentralisasi untuk komponen chat room (AppBar, Composer, Buttons, Badges).
  static ChatRoomThemeSpec getRoomThemeSpec(
    ChatThemePreference pref,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultPrimary = AppColors.blue;
    final defaultSecondary = isDark ? const Color(0xFF38BDF8) : MekaarColors.cyan;
    final defaultText = MekaarColors.textPrimaryOf(context);
    final defaultSubtitle = MekaarColors.textMutedOf(context);

    // Helper parsing Hex Color
    Color? parseHexColor(String? hex) {
      if (hex == null || hex.isEmpty) return null;
      try {
        final cleaned = hex.replaceAll('#', '').trim();
        final val = int.parse(cleaned, radix: 16);
        return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
      } catch (_) {
        return null;
      }
    }

    // 0. Custom Color Override jika pengguna memilih warna manual
    if (pref.useCustomBubbleColors) {
      final custom1 = parseHexColor(pref.outgoingColor1);
      if (custom1 != null) {
        final accent = custom1;
        final isAccentDark = accent.computeLuminance() < 0.45;
        final iconClr = isDark ? Colors.white : (isAccentDark ? accent : const Color(0xFF1E293B));
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: custom1.withValues(alpha: 0.8),
          iconColor: iconClr,
          textColor: defaultText,
          subtitleColor: defaultSubtitle,
          glassBorder: Border.all(
            color: accent.withValues(alpha: isDark ? 0.4 : 0.3),
            width: 1.2,
          ),
          glassBackgroundColor: accent.withValues(alpha: isDark ? 0.12 : 0.08),
        );
      }
    }

    // 1. Comic Pop Art
    if (pref.preset == ChatThemePreset.comic ||
        pref.preset == ChatThemePreset.comicPopArt ||
        pref.preset == ChatThemePreset.diary ||
        pref.bubbleStyle == ChatBubbleStyle.playfulOutlined) {
      if (isDark) {
        const accent = Color(0xFFEAB308);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF38BDF8),
          iconColor: accent,
          textColor: const Color(0xFFF9FAFB),
          subtitleColor: const Color(0xFF9CA3AF),
          glassBorder: Border.all(color: accent, width: 2.0),
          glassBackgroundColor: const Color(0xEE1C1427),
        );
      } else {
        const accent = Color(0xFF38BDF8);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: Colors.black,
          iconColor: Colors.black,
          textColor: Colors.black,
          subtitleColor: Colors.black87,
          glassBorder: Border.all(color: Colors.black, width: 2.0),
          glassBackgroundColor: const Color(0xEEFEF9C3),
        );
      }
    }

    // 2. Neuro / Neumorphism Soft UI
    if (pref.preset == ChatThemePreset.neuro ||
        pref.preset == ChatThemePreset.neumorphism ||
        pref.bubbleStyle == ChatBubbleStyle.neumorphicSoft) {
      final accent = isDark ? const Color(0xFF67E8F9) : const Color(0xFF0369A1);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF64748B),
        iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        glassBackgroundColor: isDark ? const Color(0x33242933) : const Color(0x33E2E8F0),
      );
    }

    // 3. Mecha Style (Tactical Armor & Cyber Grid — Menggantikan Glassmorphism)
    if (pref.preset == ChatThemePreset.mecha ||
        pref.preset == ChatThemePreset.glass ||
        pref.preset == ChatThemePreset.glassmorphism ||
        pref.preset == ChatThemePreset.fireflyNight ||
        pref.bubbleStyle == ChatBubbleStyle.mechaChamfer ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      if (isDark) {
        const accent = Color(0xFF00F0FF); // Laser Cyan
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF0284C7),
          iconColor: accent,
          textColor: const Color(0xFFE0F2FE),
          subtitleColor: const Color(0xFF38BDF8),
          glassBorder: Border.all(color: accent, width: 1.5),
          glassBackgroundColor: const Color(0xEE060B12),
        );
      } else {
        const accent = Color(0xFF0284C7); // Tactical Cobalt
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF38BDF8),
          iconColor: accent,
          textColor: defaultText,
          subtitleColor: defaultSubtitle,
          glassBorder: Border.all(color: accent, width: 1.5),
          glassBackgroundColor: const Color(0xEEEAEFF5),
        );
      }
    }

    // 4. Pixel Garden / Craft 8-Bit (Minecraft Voxel)
    if (pref.preset == ChatThemePreset.pixel ||
        pref.preset == ChatThemePreset.pixelGarden ||
        pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      if (isDark) {
        const accent = Color(0xFF5B8731);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF82B947),
          iconColor: accent,
          textColor: const Color(0xFFE2E8F0),
          subtitleColor: const Color(0xFF93C5FD),
          glassBorder: Border.all(color: accent, width: 1.5),
          glassBackgroundColor: const Color(0xEE1F1A17),
        );
      } else {
        const accent = Color(0xFF5B8731);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF82B947),
          iconColor: const Color(0xFF2D4514),
          textColor: const Color(0xFF1B2D0B),
          subtitleColor: const Color(0xFF4A2E12),
          glassBorder: Border.all(color: const Color(0xFF2D4514), width: 1.5),
          glassBackgroundColor: const Color(0xDDFFFFFF),
        );
      }
    }

    // 5. Candy Pop (Playful)
    if (pref.preset == ChatThemePreset.candy ||
        pref.preset == ChatThemePreset.candyPop ||
        pref.preset == ChatThemePreset.isometric3d ||
        pref.bubbleStyle == ChatBubbleStyle.classicRounded ||
        pref.bubbleStyle == ChatBubbleStyle.isometric3D) {
      final accent = isDark ? const Color(0xFFDB2777) : const Color(0xFFF472B6);
      final secondary = isDark ? const Color(0xFFE11D48) : const Color(0xFFFB7185);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: secondary,
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
        glassBackgroundColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
      );
    }

    // 6. Eco / Solarpunk (Calm Nature Kit)
    if (pref.preset == ChatThemePreset.eco ||
        pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      final accent = isDark ? const Color(0xFFA7B8A7) : const Color(0xFF6B7F6E);
      final secondary = isDark ? const Color(0xFF344837) : const Color(0xFF5A6D5D);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: secondary,
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: secondary.withValues(alpha: 0.4), width: 1.2),
        glassBackgroundColor: secondary.withValues(alpha: isDark ? 0.15 : 0.08),
      );
    }

    // 7. MEKAAR Core Theme (Default Fallback)
    return ChatRoomThemeSpec(
      primaryAccentColor: defaultPrimary,
      secondaryAccentColor: defaultSecondary,
      iconColor: defaultText,
      textColor: defaultText,
      subtitleColor: defaultSubtitle,
    );
  }

  /// Membangun widget wallpaper canvas sesuai preset/wallpaperType (Adaptif Light & Dark).
  static Widget buildWallpaper(ChatThemePreference pref, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (pref.wallpaperType) {
      case WallpaperType.comicHalftone:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1C1427) : const Color(0xFFFEF9C3),
            child: CustomPaint(painter: _ComicHalftonePainter(isDark: isDark)),
          ),
        );
      case WallpaperType.neumorphicCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF242933) : const Color(0xFFE2E8F0),
          ),
        );
      case WallpaperType.mechaBlueprintGrid:
      case WallpaperType.gradient: // Fallback legacy glass
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF060B12) : const Color(0xFFEAEFF5),
            child: CustomPaint(painter: _MechaBlueprintPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.pixelGardenCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1F1A17) : const Color(0xFF99C272),
            child: CustomPaint(painter: _PixelVoxelPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.pattern:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF231221) : const Color(0xFFFDF2F8),
            child: CustomPaint(painter: _CandyPolkaPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.solarpunkCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF172119) : const Color(0xFFF4EFE8),
            child: CustomPaint(painter: _SolarPunkGrainPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.solidColor:
        final hex = int.tryParse(pref.wallpaperValue ?? '');
        if (hex != null) {
          return Positioned.fill(child: Container(color: Color(hex)));
        }
        return _buildMekaarCleanWallpaper(context);
      case WallpaperType.customImage:
        if (pref.wallpaperValue != null && pref.wallpaperValue!.isNotEmpty) {
          final file = File(pref.wallpaperValue!);
          if (file.existsSync()) {
            return Positioned.fill(
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildMekaarCleanWallpaper(context);
                },
              ),
            );
          }
        }
        return _buildMekaarCleanWallpaper(context);
      case WallpaperType.dynamicTime:
      default:
        return _buildMekaarCleanWallpaper(context);
    }
  }

  static Widget _buildMekaarCleanWallpaper(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Container(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      ),
    );
  }

  static Widget _buildPixelHeader({required bool isMe, required bool isDark}) {
    final text = isMe ? '❖ [SENT.8BIT]' : '❖ [RECV.8BIT]';
    Color color;
    if (isDark) {
      color = isMe ? const Color(0xFF82B947) : const Color(0xFF686868);
    } else {
      color = isMe ? const Color(0xFF82B947) : const Color(0xFF8C734B);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

// ── Custom Painters untuk Canvas Background 60fps (Adaptif Light & Dark) ──────

class _ComicHalftonePainter extends CustomPainter {
  final bool isDark;
  _ComicHalftonePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF38264E) : const Color(0xFFFDE047);
    const step = 12.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x + 6, y + 6), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MechaBlueprintPainter extends CustomPainter {
  final bool isDark;
  _MechaBlueprintPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final gridPaint = Paint()
      ..color = isDark ? const Color(0x1800F0FF) : const Color(0xFFDCE4EE)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PixelVoxelPainter extends CustomPainter {
  final bool isDark;
  _PixelVoxelPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final voxelPaint = Paint()
      ..color = isDark ? const Color(0xFF181412) : const Color(0xFF8CB865);

    const step = 16.0;
    const half = step / 2;
    for (double y = 0; y < size.height; y += step) {
      final rowOdd = ((y / step).floor() % 2 == 1);
      for (double x = 0; x < size.width; x += step) {
        final colOdd = ((x / step).floor() % 2 == 1);
        if (rowOdd ^ colOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, half, half), voxelPaint);
          canvas.drawRect(Rect.fromLTWH(x + half, y + half, half, half), voxelPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CandyPolkaPainter extends CustomPainter {
  final bool isDark;
  _CandyPolkaPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF3D1E38) : const Color(0xFFFBCFE8);
    const step = 14.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x + 7, y + 7), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SolarPunkGrainPainter extends CustomPainter {
  final bool isDark;
  _SolarPunkGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF263629) : const Color(0xFFC9BDAF);
    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x + 9, y + 9), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
