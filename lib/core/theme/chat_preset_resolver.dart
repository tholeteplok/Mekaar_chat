import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/chat_theme_model.dart';
import '../constants/colors.dart';
import '../constants/icons.dart';
import '../constants/shadows.dart';

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
  dynamicTimeFadeSlide,
  fireflySlowGlow,
  diaryWritingSlideLeft,
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

/// Resolver tersentralisasi untuk 12 Preset Tema Chat Mekaar.
class ChatPresetResolver {
  ChatPresetResolver._();

  /// Mendapatkan spesifikasi animasi masuk signature untuk preset tema yang dipilih.
  static BubbleEntranceSpec getEntranceAnimation(ChatThemePreset preset) {
    switch (preset) {
      case ChatThemePreset.neumorphism:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          type: EntranceType.neumorphismSoft,
        );
      case ChatThemePreset.glassmorphism:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOut,
          type: EntranceType.glassmorphismBlur,
        );
      case ChatThemePreset.pixelGarden:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOut,
          type: EntranceType.pixelGlitchStep,
        );
      case ChatThemePreset.neonDreams:
      case ChatThemePreset.neonCyberpunk:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 200),
          curve: Curves.linear,
          type: EntranceType.neonFlickerGlow,
        );
      case ChatThemePreset.candyPop:
      case ChatThemePreset.isometric3d:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.elasticOut,
          type: EntranceType.comicPopElastic,
        );
      case ChatThemePreset.retroWave:
      case ChatThemePreset.retroY2K:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          type: EntranceType.retroY2KHeaderFirst,
        );
      case ChatThemePreset.monoVibe:
      case ChatThemePreset.swissMinimalist:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeInOutQuart,
          type: EntranceType.swissRevealHorizontal,
        );
      case ChatThemePreset.solarpunk:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          type: EntranceType.solarpunkGrowth,
        );
      case ChatThemePreset.comicPopArt:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.elasticOut,
          type: EntranceType.comicPopElastic,
        );
      case ChatThemePreset.fireflyNight:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 450),
          curve: Curves.easeInOutSine,
          type: EntranceType.fireflySlowGlow,
        );
      case ChatThemePreset.diary:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 240),
          curve: Curves.easeOut,
          type: EntranceType.diaryWritingSlideLeft,
        );
      case ChatThemePreset.dynamicTime:
      case ChatThemePreset.custom:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          type: EntranceType.dynamicTimeFadeSlide,
        );
    }
  }

  /// Mendapatkan spesifikasi visual gelembung obrolan berdasarkan preferensi & posisi (pengirim/penerima).
  static ChatBubbleSpec getBubbleSpec(
    ChatThemePreference pref,
    BuildContext context, {
    required bool isMe,
    double baseFontSize = 16.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = baseFontSize * pref.textScale;

    // Helper untuk meresolusi TextStyle sesuai Preset Font
    TextStyle resolveTextStyle(Color textColor) {
      try {
        switch (pref.preset) {
          case ChatThemePreset.neonDreams:
          case ChatThemePreset.neonCyberpunk:
            return GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              letterSpacing: 0.2,
              fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
            );
          case ChatThemePreset.candyPop:
          case ChatThemePreset.isometric3d:
            return GoogleFonts.fredoka(
              color: textColor,
              fontSize: fontSize,
              height: 1.3,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.comicPopArt:
            return GoogleFonts.comicNeue(
              color: textColor,
              fontSize: fontSize + 1,
              height: 1.3,
              fontWeight: FontWeight.w700,
            );
          case ChatThemePreset.neumorphism:
            return GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              fontWeight: FontWeight.w500,
            );
          case ChatThemePreset.glassmorphism:
            return GoogleFonts.outfit(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            );
          case ChatThemePreset.pixelGarden:
            return GoogleFonts.dotGothic16(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.retroWave:
          case ChatThemePreset.retroY2K:
            return GoogleFonts.orbitron(
              color: textColor,
              fontSize: fontSize - 1,
              height: 1.3,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.monoVibe:
          case ChatThemePreset.swissMinimalist:
            return GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w700,
            );
          case ChatThemePreset.solarpunk:
            return GoogleFonts.comfortaa(
              color: textColor,
              fontSize: fontSize - 1,
              height: 1.4,
              fontWeight: FontWeight.w600,
            );
          case ChatThemePreset.fireflyNight:
            return GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              fontWeight: FontWeight.w500,
            );
          case ChatThemePreset.diary:
            return GoogleFonts.kalam(
              color: textColor,
              fontSize: fontSize + 2,
              height: 1.35,
              fontWeight: FontWeight.w700,
            );
          case ChatThemePreset.dynamicTime:
          case ChatThemePreset.custom:
            return GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
            );
        }
      } catch (_) {
        return TextStyle(
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
          textStyle: resolveTextStyle(txtColor),
        );
      }
    }

    // 1. Neumorphism / Soft UI
    if (pref.preset == ChatThemePreset.neumorphism ||
        pref.bubbleStyle == ChatBubbleStyle.neumorphicSoft) {
      final baseBg = isDark ? const Color(0xFF242A38) : const Color(0xFFE2E8F0);
      final txt = isDark ? Colors.white : (isMe ? const Color(0xFF1A202C) : const Color(0xFF2D3748));
      if (isMe) {
        return ChatBubbleSpec(
          backgroundColor: isDark ? const Color(0xFF2D3546) : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.6) : const Color(0xFFA0AEC0),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: isDark ? const Color(0xFF3A445A) : Colors.white,
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        return ChatBubbleSpec(
          backgroundColor: baseBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 2. Glassmorphism / Frosted Glass
    if (pref.preset == ChatThemePreset.glassmorphism ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      final txt = isMe ? Colors.white : MekaarColors.textPrimaryOf(context);
      if (isMe) {
        return ChatBubbleSpec(
          backgroundColor: isDark ? const Color(0x668B5CF6) : const Color(0x773B82F6),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.6),
            width: 1.2,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                  .withValues(alpha: 0.25),
              blurRadius: 12,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        return ChatBubbleSpec(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.65),
            width: 1.2,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 3. Pixel Garden 8-Bit (Bluebloom)
    if (pref.preset == ChatThemePreset.pixelGarden ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      if (isMe) {
        const txt = Color(0xFFF5F3EF);
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF3B567D),
          border: Border.all(color: const Color(0xFF1B2A4A), width: 1.5),
          borderRadius: BorderRadius.zero,
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF1B2A4A),
              offset: Offset(2.5, 2.5),
              blurRadius: 0,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
          headerWidget: _buildPixelHeader(isMe: true),
        );
      } else {
        const txt = Color(0xFF1B2A4A);
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFFF7F5F0),
          border: Border.all(color: const Color(0xFF3B567D), width: 1.5),
          borderRadius: BorderRadius.zero,
          boxShadow: const [
            BoxShadow(
              color: Color(0x333B567D),
              offset: Offset(2.5, 2.5),
              blurRadius: 0,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
          headerWidget: _buildPixelHeader(isMe: false),
        );
      }
    }

    // 4. Candy Pop (Playful Youth)
    if (pref.preset == ChatThemePreset.candyPop ||
        pref.preset == ChatThemePreset.isometric3d ||
        pref.bubbleStyle == ChatBubbleStyle.isometric3D) {
      if (isMe) {
        const txt = Colors.white;
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFFFF6B9D), // Candy Pink
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29FF6B9D),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        const txt = Color(0xFF1A2B2C); // Dark teal text
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF4ECDC4), // Candy Mint
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x294ECDC4),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 5. Retro Wave (Nostalgic Youth)
    if (pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.retroBevel) {
      if (isMe) {
        const txt = Colors.white;
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFFFF006E),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFC0C0C0), width: 1.2), // Chrome border
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x408338EC),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        const txt = Color(0xFFE2E8F0);
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF1A1128), // Metallic dark purple
          border: Border.all(color: const Color(0xFFC0C0C0), width: 1.2), // Chrome border
          borderRadius: BorderRadius.circular(18),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 6. Mono Vibe (Minimalist Youth)
    if (pref.preset == ChatThemePreset.monoVibe ||
        pref.preset == ChatThemePreset.swissMinimalist ||
        pref.bubbleStyle == ChatBubbleStyle.swissSquare) {
      if (isMe) {
        const txt = Color(0xFF39FF14); // Lime accent text
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF39FF14), width: 1.5), // Lime accent
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF39FF14).withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        final txt = isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
        return ChatBubbleSpec(
          backgroundColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(14),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 7. Solarpunk / Organic Eco-Tech
    if (pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      if (isMe) {
        const txt = Colors.white;
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF10B981),
          border: Border.all(color: const Color(0xFF059669), width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(2),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3310B981),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        final txt = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46);
        return ChatBubbleSpec(
          backgroundColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(24),
          ),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 8. Neon Dreams (Night Youth)
    if (pref.preset == ChatThemePreset.neonDreams ||
        pref.preset == ChatThemePreset.neonCyberpunk ||
        pref.bubbleStyle == ChatBubbleStyle.cyberEdge) {
      if (isMe) {
        const txt = Color(0xFF00F5D4); // Neon Teal text
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF0F0B1E), // Deep purple-black
          border: Border.all(color: const Color(0xFF00F5D4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5D4).withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        const txt = Color(0xFFE2E8F0);
        return ChatBubbleSpec(
          backgroundColor: const Color(0xFF1E1535), // Dark purple
          border: Border.all(
            color: const Color(0xFFFF006E).withValues(alpha: 0.5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF006E).withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 9. Comic Pop Art
    if (pref.preset == ChatThemePreset.comicPopArt ||
        pref.bubbleStyle == ChatBubbleStyle.playfulOutlined) {
      const txt = Colors.black;
      return ChatBubbleSpec(
        backgroundColor: isMe ? const Color(0xFFFFD84D) : Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2.5, 2.5)),
        ],
        textColor: txt,
        textStyle: resolveTextStyle(txt),
      );
    }

    // 10. Kunang-kunang / Firefly Night
    if (pref.preset == ChatThemePreset.fireflyNight ||
        pref.bubbleStyle == ChatBubbleStyle.fireflyAmber) {
      const txt = Color(0xFFF5E9D3);
      if (isMe) {
        return ChatBubbleSpec(
          backgroundColor: const Color(0x33F5C97D),
          border: Border.all(color: const Color(0x40F5C97D), width: 1),
          borderRadius: BorderRadius.circular(22),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      } else {
        return ChatBubbleSpec(
          backgroundColor: const Color(0x14FFFFFF),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          borderRadius: BorderRadius.circular(22),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
        );
      }
    }

    // 11. Buku Harian / Diary
    if (pref.preset == ChatThemePreset.diary ||
        pref.bubbleStyle == ChatBubbleStyle.diaryHandwriting) {
      if (isMe) {
        const txt = Color(0xFF1E3A8A); // Biru Tinta
        return ChatBubbleSpec(
          backgroundColor: const Color(0x0A1E3A8A),
          borderRadius: BorderRadius.circular(8),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
          headerWidget: _buildDiaryStampHeader(isMe: true),
        );
      } else {
        const txt = Color(0xFF1C1917); // Hitam Pensil / Pulpen
        return ChatBubbleSpec(
          backgroundColor: const Color(0x05000000),
          borderRadius: BorderRadius.circular(8),
          textColor: txt,
          textStyle: resolveTextStyle(txt),
          headerWidget: _buildDiaryStampHeader(isMe: false),
        );
      }
    }

    // 12. Dynamic Time (Fallback / Default)
    final bg = isMe
        ? MekaarColors.outgoingBubbleOf(context)
        : MekaarColors.surfaceOf(context);
    final txt = isMe
        ? MekaarColors.outgoingTextOf(context)
        : MekaarColors.textPrimaryOf(context);

    return ChatBubbleSpec(
      backgroundColor: bg,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 18),
      ),
      boxShadow: (isMe ? null : MekaarShadows.bubble),
      textColor: txt,
      textStyle: resolveTextStyle(txt),
    );
  }

  /// Mendapatkan spesifikasi tema tersentralisasi untuk komponen chat room (AppBar, Composer, Buttons, Badges).
  static ChatRoomThemeSpec getRoomThemeSpec(
    ChatThemePreference pref,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultPrimary = MekaarColors.softCoral;
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

    // 1. Neumorphism
    if (pref.preset == ChatThemePreset.neumorphism ||
        pref.bubbleStyle == ChatBubbleStyle.neumorphicSoft) {
      final accent = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
        iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        glassBackgroundColor: isDark ? const Color(0x33242A38) : const Color(0x33E2E8F0),
      );
    }

    // 2. Glassmorphism
    if (pref.preset == ChatThemePreset.glassmorphism ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      final accent = isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF3B82F6),
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.6),
          width: 1.2,
        ),
        glassBackgroundColor: isDark ? const Color(0x228B5CF6) : const Color(0x183B82F6),
      );
    }

    // 3. Pixel Garden 8-Bit
    if (pref.preset == ChatThemePreset.pixelGarden ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      const accent = Color(0xFF3B567D);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF5B769D),
        iconColor: const Color(0xFF1B2A4A),
        textColor: const Color(0xFF1B2A4A),
        subtitleColor: const Color(0xFF3B567D),
        glassBorder: Border.all(color: const Color(0xFF1B2A4A), width: 1.5),
        glassBackgroundColor: const Color(0xDDFFFFFF),
      );
    }

    // 4. Candy Pop
    if (pref.preset == ChatThemePreset.candyPop ||
        pref.preset == ChatThemePreset.isometric3d ||
        pref.bubbleStyle == ChatBubbleStyle.isometric3D) {
      const accent = Color(0xFFFF6B9D);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF4ECDC4),
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
        glassBackgroundColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
      );
    }

    // 5. Retro Wave
    if (pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.retroBevel) {
      const accent = Color(0xFFFF006E);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF8338EC),
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: const Color(0xFFC0C0C0), width: 1.2),
        glassBackgroundColor: const Color(0x661A1128),
      );
    }

    // 6. Mono Vibe
    if (pref.preset == ChatThemePreset.monoVibe ||
        pref.preset == ChatThemePreset.swissMinimalist ||
        pref.bubbleStyle == ChatBubbleStyle.swissSquare) {
      const accent = Color(0xFF39FF14);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1A1A),
        iconColor: accent,
        textColor: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1A1A),
        subtitleColor: accent,
        glassBorder: Border.all(color: accent, width: 1.5),
        glassBackgroundColor: const Color(0xAA1A1A1A),
      );
    }

    // 7. Solarpunk
    if (pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      const accent = Color(0xFF10B981);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF059669),
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4), width: 1.2),
        glassBackgroundColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
      );
    }

    // 8. Neon Dreams
    if (pref.preset == ChatThemePreset.neonDreams ||
        pref.preset == ChatThemePreset.neonCyberpunk ||
        pref.bubbleStyle == ChatBubbleStyle.cyberEdge) {
      const accent = Color(0xFF00F5D4);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFFFF006E),
        iconColor: accent,
        textColor: accent,
        subtitleColor: const Color(0xFFFF006E),
        glassBorder: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
        glassBackgroundColor: const Color(0xAA0F0B1E),
      );
    }

    // 9. Comic Pop Art
    if (pref.preset == ChatThemePreset.comicPopArt ||
        pref.bubbleStyle == ChatBubbleStyle.playfulOutlined) {
      const accent = Color(0xFFFFD84D);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: Colors.black,
        iconColor: Colors.black,
        textColor: Colors.black,
        subtitleColor: Colors.black87,
        glassBorder: Border.all(color: Colors.black, width: 2.0),
        glassBackgroundColor: const Color(0xEEFFFDF0),
      );
    }

    // 10. Kunang-kunang / Firefly Night
    if (pref.preset == ChatThemePreset.fireflyNight ||
        pref.bubbleStyle == ChatBubbleStyle.fireflyAmber) {
      const accent = Color(0xFFF5C97D);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFFFBF0B9),
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: accent.withValues(alpha: 0.3), width: 1.0),
        glassBackgroundColor: const Color(0x22F5C97D),
      );
    }

    // 11. Buku Harian / Diary
    if (pref.preset == ChatThemePreset.diary ||
        pref.bubbleStyle == ChatBubbleStyle.diaryHandwriting) {
      const accent = Color(0xFF1E3A8A);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: const Color(0xFF3B82F6),
        iconColor: accent,
        textColor: const Color(0xFF1E3A8A),
        subtitleColor: const Color(0xFF3B82F6),
        glassBorder: Border.all(color: accent.withValues(alpha: 0.25), width: 1.0),
        glassBackgroundColor: const Color(0x111E3A8A),
      );
    }

    // 12. Dynamic Time (Default Fallback)
    return ChatRoomThemeSpec(
      primaryAccentColor: defaultPrimary,
      secondaryAccentColor: defaultSecondary,
      iconColor: defaultText,
      textColor: defaultText,
      subtitleColor: defaultSubtitle,
    );
  }

  /// Membangun widget wallpaper canvas sesuai preset/wallpaperType.
  static Widget buildWallpaper(ChatThemePreference pref, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (pref.wallpaperType) {
      case WallpaperType.neumorphicCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1E2430) : const Color(0xFFE2E8F0),
          ),
        );
      case WallpaperType.pixelGardenCanvas:
        return Positioned.fill(
          child: Container(
            color: const Color(0xFFEFECE6),
            child: CustomPaint(painter: _PixelGardenPainter()),
          ),
        );
      case WallpaperType.isometricGrid:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: CustomPaint(painter: _IsometricGridPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.retroY2KCanvas:
        return Positioned.fill(
          child: Container(
            color: const Color(0xFF008080), // Classic Win95 Teal Desktop
          ),
        );
      case WallpaperType.swissGrid:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
            child: CustomPaint(painter: _SwissGridPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.solarpunkCanvas:
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF064E3B), Color(0xFF022C22)]
                    : const [Color(0xFFECFDF5), Color(0xFFFEF3C7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        );
      case WallpaperType.neonGrid:
        return Positioned.fill(
          child: Container(
            color: const Color(0xFF0B0E14),
            child: CustomPaint(painter: _NeonGridPainter()),
          ),
        );
      case WallpaperType.comicHalftone:
        return Positioned.fill(
          child: Container(
            color: const Color(0xFFFFFDF0),
            child: CustomPaint(painter: _ComicHalftonePainter()),
          ),
        );
      case WallpaperType.solidColor:
        final hex = int.tryParse(pref.wallpaperValue ?? '') ??
            (isDark ? 0xFF0F172A : 0xFFF8FAFF);
        return Positioned.fill(child: Container(color: Color(hex)));
      case WallpaperType.fireflyCanvas:
        return const Positioned.fill(
          child: _FireflyWallpaperWidget(),
        );
      case WallpaperType.diaryRuledPaper:
        return Positioned.fill(
          child: Container(
            color: const Color(0xFFFBF8EE),
            child: CustomPaint(painter: _RuledPaperPainter()),
          ),
        );
      case WallpaperType.gradient:
        return Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      case WallpaperType.customImage:
        if (pref.wallpaperValue != null && pref.wallpaperValue!.isNotEmpty) {
          final file = File(pref.wallpaperValue!);
          if (file.existsSync()) {
            return Positioned.fill(
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDynamicTimeWallpaper(context);
                },
              ),
            );
          }
        }
        return _buildDynamicTimeWallpaper(context);
      case WallpaperType.pattern:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: CustomPaint(painter: _PatternWallpaperPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.dynamicTime:
        return _buildDynamicTimeWallpaper(context);
    }
  }

  static Widget _buildDynamicTimeWallpaper(BuildContext context) {
    final hour = DateTime.now().hour;
    LinearGradient timeGradient;
    if (hour >= 5 && hour < 11) {
      timeGradient = MekaarGradients.canvasMorning;
    } else if (hour >= 11 && hour < 15) {
      timeGradient = MekaarGradients.canvasAfternoon;
    } else if (hour >= 15 && hour < 18) {
      timeGradient = MekaarGradients.canvasEvening;
    } else {
      timeGradient = MekaarGradients.canvasDark;
    }
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(gradient: timeGradient),
      ),
    );
  }

  static Widget _buildDiaryStampHeader({required bool isMe}) {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final textColor = isMe
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.6)
        : const Color(0xFF1C1917).withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MekaarIcons.editNote, size: 12, color: textColor),
          const SizedBox(width: 3),
          Text(
            '// $dateStr',
            style: TextStyle(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              fontFamily: 'monospace',
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPixelHeader({required bool isMe}) {
    final text = isMe ? '❖ [SENT.8BIT]' : '❖ [RECV.8BIT]';
    final color = isMe ? const Color(0xFF90B0D8) : const Color(0xFF4B6B94);
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

// ── Stateful Animated Wallpaper untuk Kunang-kunang (Firefly Night) ───────────

class _FireflyWallpaperWidget extends StatefulWidget {
  const _FireflyWallpaperWidget();

  @override
  State<_FireflyWallpaperWidget> createState() => _FireflyWallpaperWidgetState();
}

class _FireflyWallpaperWidgetState extends State<_FireflyWallpaperWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pause animation if route is not current to conserve CPU & battery
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent && _controller.isAnimating) {
      _controller.stop();
    } else if (isCurrent && !_controller.isAnimating) {
      _controller.repeat();
    }

    return Container(
      color: const Color(0xFF0B1226),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _FireflyPainter(progress: _controller.value),
          );
        },
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  final double progress;

  _FireflyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rand = math.Random(42); // Fixed seed for stable positions across rebuilds
    const fireflyCount = 18;

    for (int i = 0; i < fireflyCount; i++) {
      final xPct = rand.nextDouble();
      final yPct = rand.nextDouble();
      final radius = 1.5 + rand.nextDouble() * 1.0;
      final speed = 1.0 + rand.nextDouble() * 2.0;
      final phase = rand.nextDouble() * 6.28318;

      final x = xPct * size.width;
      final y = yPct * size.height;

      final rawSine = (progress * 6.28318 * speed + phase);
      final pulse = math.sin(rawSine);
      final opacity = (0.15 + 0.55 * (0.5 + 0.5 * pulse)).clamp(0.0, 1.0);

      // Glow radial gradient
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF5C97D).withValues(alpha: opacity),
            const Color(0xFFF5C97D).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius * 3.5));

      canvas.drawCircle(Offset(x, y), radius * 3.5, glowPaint);

      // Core dot
      final corePaint = Paint()
        ..color = const Color(0xFFFFF4D6).withValues(alpha: opacity * 0.95);
      canvas.drawCircle(Offset(x, y), radius, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RuledPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Horizontal blue-ruled lines ~28px apart
    final linePaint = Paint()
      ..color = const Color(0x1A3B82F6)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double y = 40.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Vertical pink margin line at ~32px from left
    final marginPaint = Paint()
      ..color = const Color(0x33EF4444)
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(32, 0), Offset(32, size.height), marginPaint);

    // 3. Subtle paper crease lines at top-right corner
    final creasePaint = Paint()
      ..color = const Color(0x0D000000)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(size.width - 40, 0), Offset(size.width, 40), creasePaint);
    canvas.drawLine(Offset(size.width - 20, 0), Offset(size.width, 20), creasePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Painters untuk Canvas Background ─────────────────────────────────

class _PixelGardenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0x184B6B94)
      ..strokeWidth = 1.0;

    // 1. Subtle 8-bit dither grid lines ~24px apart
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Pixel flower motifs (❖ 4-petal pixel cross) scattered across background
    final flowerPaint = Paint()..color = const Color(0x354B6B94);
    final rand = math.Random(101);
    const flowerCount = 14;

    for (int i = 0; i < flowerCount; i++) {
      final cx = (rand.nextDouble() * size.width / step).floor() * step + step / 2;
      final cy = (rand.nextDouble() * size.height / step).floor() * step + step / 2;
      const pSize = 3.0;

      // Draw 4-petal pixel flower plus shape
      canvas.drawRect(Rect.fromLTWH(cx - pSize * 1.5, cy - pSize * 0.5, pSize, pSize), flowerPaint);
      canvas.drawRect(Rect.fromLTWH(cx + pSize * 0.5, cy - pSize * 0.5, pSize, pSize), flowerPaint);
      canvas.drawRect(Rect.fromLTWH(cx - pSize * 0.5, cy - pSize * 1.5, pSize, pSize), flowerPaint);
      canvas.drawRect(Rect.fromLTWH(cx - pSize * 0.5, cy + pSize * 0.5, pSize, pSize), flowerPaint);
    }

    // 3. Pixel mountain silhouette along bottom canvas
    final mountainPaint = Paint()..color = const Color(0x20708CAE);
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height - 45);
    path.lineTo(size.width * 0.2, size.height - 75);
    path.lineTo(size.width * 0.45, size.height - 35);
    path.lineTo(size.width * 0.75, size.height - 85);
    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, mountainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IsometricGridPainter extends CustomPainter {
  final bool isDark;
  _IsometricGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x15FFFFFF) : const Color(0x15000000)
      ..strokeWidth = 0.8;
    const step = 32.0;

    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwissGridPainter extends CustomPainter {
  final bool isDark;
  _SwissGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x10FFFFFF) : const Color(0x10000000)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2200F0FF)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ComicHalftonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x15000000);
    const step = 16.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatternWallpaperPainter extends CustomPainter {
  final bool isDark;
  _PatternWallpaperPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000)
      ..strokeWidth = 1.0;
    const step = 24.0;

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x + 12, y + 12), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
