import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/chat_theme_model.dart';
import '../constants/colors.dart';
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
      case ChatThemePreset.glass:
      case ChatThemePreset.glassmorphism:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOut,
          type: EntranceType.glassmorphismBlur,
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
      case ChatThemePreset.fireflyNight:
        return const BubbleEntranceSpec(
          duration: Duration(milliseconds: 450),
          curve: Curves.easeInOutSine,
          type: EntranceType.fireflySlowGlow,
        );
      case ChatThemePreset.mekaar:
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
            return GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              fontWeight: FontWeight.w500,
            );
          case ChatThemePreset.glass:
          case ChatThemePreset.glassmorphism:
          case ChatThemePreset.fireflyNight:
            return GoogleFonts.outfit(
              color: textColor,
              fontSize: fontSize,
              height: 1.4,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
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
            return GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: fontSize,
              height: 1.35,
              letterSpacing: 0.2,
              fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
            );
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

    // 1. Comic Pop Art
    if (pref.preset == ChatThemePreset.comic ||
        pref.preset == ChatThemePreset.comicPopArt ||
        pref.preset == ChatThemePreset.diary ||
        pref.bubbleStyle == ChatBubbleStyle.playfulOutlined) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.black;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFF59E0B), // Saturated Amber Gold
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(2.5, 2.5)),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFF9FAFB);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF1F2937), // Dark Charcoal
            border: Border.all(color: const Color(0xFF4B5563), width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(2.5, 2.5)),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      } else {
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
    }

    // 2. Neuro / Neumorphism Soft UI
    if (pref.preset == ChatThemePreset.neuro ||
        pref.preset == ChatThemePreset.neumorphism ||
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

    // 3. Glassmorphism / Frosted Glass
    if (pref.preset == ChatThemePreset.glass ||
        pref.preset == ChatThemePreset.glassmorphism ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0x668B5CF6), // Royal Purple Frosted
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFF1F5F9);
          return ChatBubbleSpec(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
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
      } else {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0x773B82F6), // Sky Blue Frosted
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
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
                color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFF1E293B);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xCCFFFFFF), // Frosted Pearl White
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.2,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        }
      }
    }

    // 4. Pixel Garden 8-Bit (Arcade)
    if (pref.preset == ChatThemePreset.pixel ||
        pref.preset == ChatThemePreset.pixelGarden ||
        pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF2563EB), // Electric Blue Arcade
            border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                offset: Offset(2.5, 2.5),
                blurRadius: 0,
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
            headerWidget: _buildPixelHeader(isMe: true, isDark: true),
          );
        } else {
          const txt = Color(0xFFE2E8F0);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF1E293B), // Cyber Slate
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            borderRadius: BorderRadius.zero,
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                offset: Offset(2.5, 2.5),
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
            headerWidget: _buildPixelHeader(isMe: true, isDark: false),
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
            backgroundColor: const Color(0xFFF43F5E), // Neon Rose
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40F43F5E),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFF0FDFA);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF0D9488), // Neon Teal
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330D9488),
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
    }

    // 6. Eco / Solarpunk (Organic Leaf)
    if (pref.preset == ChatThemePreset.eco ||
        pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      if (isDark) {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF059669), // Forest Emerald
            border: Border.all(color: const Color(0xFF047857), width: 1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40059669),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
            textColor: txt,
            textStyle: resolveTextStyle(txt),
          );
        } else {
          const txt = Color(0xFFD1FAE5);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF064E3B), // Jungle Moss
            border: Border.all(color: const Color(0xFF047857), width: 1),
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
      } else {
        if (isMe) {
          const txt = Colors.white;
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFF10B981), // Fresh Emerald
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
          const txt = Color(0xFF065F46);
          return ChatBubbleSpec(
            backgroundColor: const Color(0xFFECFDF5), // Fresh Sage
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
    }

    // 7. MEKAAR Clean Theme (Default Fallback)
    if (isMe) {
      return ChatBubbleSpec(
        backgroundColor: AppColors.blue,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        textColor: AppColors.textOnBlue,
        textStyle: resolveTextStyle(AppColors.textOnBlue),
      );
    } else {
      final bg = isDark ? const Color(0xFF1E304F) : Colors.white;
      final txt = isDark ? const Color(0xFFF4F9FF) : AppColors.darkBlue;
      final borderColor = isDark ? const Color(0xFF25395B) : const Color(0xFFDCE7F5);

      return ChatBubbleSpec(
        backgroundColor: bg,
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: MekaarShadows.bubble,
        textColor: txt,
        textStyle: resolveTextStyle(txt),
      );
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
        const accent = Color(0xFFF59E0B);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFFE5E7EB),
          iconColor: accent,
          textColor: const Color(0xFFF9FAFB),
          subtitleColor: const Color(0xFF9CA3AF),
          glassBorder: Border.all(color: accent, width: 2.0),
          glassBackgroundColor: const Color(0xEE111827),
        );
      } else {
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
    }

    // 2. Neuro / Neumorphism Soft UI
    if (pref.preset == ChatThemePreset.neuro ||
        pref.preset == ChatThemePreset.neumorphism ||
        pref.bubbleStyle == ChatBubbleStyle.neumorphicSoft) {
      final accent = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
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
        glassBackgroundColor: isDark ? const Color(0x33242A38) : const Color(0x33E2E8F0),
      );
    }

    // 3. Glassmorphism / Frosted Glass
    if (pref.preset == ChatThemePreset.glass ||
        pref.preset == ChatThemePreset.glassmorphism ||
        pref.bubbleStyle == ChatBubbleStyle.glassmorphism) {
      final accent = isDark ? const Color(0xFFA78BFA) : const Color(0xFF3B82F6);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF8B5CF6),
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

    // 4. Pixel Garden 8-Bit (Arcade)
    if (pref.preset == ChatThemePreset.pixel ||
        pref.preset == ChatThemePreset.pixelGarden ||
        pref.preset == ChatThemePreset.retroWave ||
        pref.preset == ChatThemePreset.retroY2K ||
        pref.bubbleStyle == ChatBubbleStyle.pixelGardenStyle) {
      if (isDark) {
        const accent = Color(0xFF38BDF8);
        return ChatRoomThemeSpec(
          primaryAccentColor: accent,
          secondaryAccentColor: const Color(0xFF2563EB),
          iconColor: accent,
          textColor: const Color(0xFFE2E8F0),
          subtitleColor: const Color(0xFF93C5FD),
          glassBorder: Border.all(color: accent, width: 1.5),
          glassBackgroundColor: const Color(0xEE0B132B),
        );
      } else {
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
    }

    // 5. Candy Pop (Playful)
    if (pref.preset == ChatThemePreset.candy ||
        pref.preset == ChatThemePreset.candyPop ||
        pref.preset == ChatThemePreset.isometric3d ||
        pref.bubbleStyle == ChatBubbleStyle.classicRounded ||
        pref.bubbleStyle == ChatBubbleStyle.isometric3D) {
      final accent = isDark ? const Color(0xFFFB7185) : const Color(0xFFFF6B9D);
      final secondary = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4ECDC4);
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

    // 6. Eco / Solarpunk (Organic Leaf)
    if (pref.preset == ChatThemePreset.eco ||
        pref.preset == ChatThemePreset.solarpunk ||
        pref.bubbleStyle == ChatBubbleStyle.solarpunkLeaf) {
      final accent = isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
      final secondary = const Color(0xFF059669);
      return ChatRoomThemeSpec(
        primaryAccentColor: accent,
        secondaryAccentColor: secondary,
        iconColor: accent,
        textColor: defaultText,
        subtitleColor: defaultSubtitle,
        glassBorder: Border.all(color: secondary.withValues(alpha: 0.4), width: 1.2),
        glassBackgroundColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
      );
    }

    // 7. MEKAAR Clean Theme (Default Fallback)
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
            color: isDark ? const Color(0xFF111827) : const Color(0xFFFFFDF0),
            child: CustomPaint(painter: _ComicHalftonePainter(isDark: isDark)),
          ),
        );
      case WallpaperType.neumorphicCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1E2430) : const Color(0xFFE2E8F0),
          ),
        );
      case WallpaperType.gradient:
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF1E1B4B), Color(0xFF0F172A)]
                    : const [Color(0xFFE0E7FF), Color(0xFFBAE6FD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      case WallpaperType.pixelGardenCanvas:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF0B132B) : const Color(0xFFEFECE6),
            child: CustomPaint(painter: _PixelGardenPainter(isDark: isDark)),
          ),
        );
      case WallpaperType.pattern:
        return Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF1E112A) : const Color(0xFFFFF5F7),
            child: CustomPaint(painter: _PatternWallpaperPainter(isDark: isDark)),
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
      case WallpaperType.solidColor:
        final hex = int.tryParse(pref.wallpaperValue ?? '') ??
            (isDark ? 0xFF0F172A : 0xFFF8FAFF);
        return Positioned.fill(child: Container(color: Color(hex)));
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
      case WallpaperType.dynamicTime:
      default:
        return _buildDynamicTimeWallpaper(context);
    }
  }

  static Widget _buildDynamicTimeWallpaper(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  static Widget _buildPixelHeader({required bool isMe, required bool isDark}) {
    final text = isMe ? '❖ [SENT.8BIT]' : '❖ [RECV.8BIT]';
    Color color;
    if (isDark) {
      color = isMe ? const Color(0xFF93C5FD) : const Color(0xFF38BDF8);
    } else {
      color = isMe ? const Color(0xFF90B0D8) : const Color(0xFF4B6B94);
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

// ── Custom Painters untuk Canvas Background (Adaptif Light & Dark) ───────────

class _ComicHalftonePainter extends CustomPainter {
  final bool isDark;
  _ComicHalftonePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x22374151) : const Color(0x15000000);
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

class _PixelGardenPainter extends CustomPainter {
  final bool isDark;
  _PixelGardenPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0x1838BDF8) : const Color(0x184B6B94)
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
    final flowerPaint = Paint()
      ..color = isDark ? const Color(0x3538BDF8) : const Color(0x354B6B94);
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
    final mountainPaint = Paint()
      ..color = isDark ? const Color(0x201E3A8A) : const Color(0x20708CAE);
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

class _PatternWallpaperPainter extends CustomPainter {
  final bool isDark;
  _PatternWallpaperPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x2EFB7185) : const Color(0x1FDD5A8C)
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
