import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/chat_theme_model.dart';
import '../providers/chat_theme_provider.dart';

/// Layar Kustomisasi Tema Chat: Live Preview, Selector Dropdown, Wallpaper & Ukuran Teks.
class ChatThemeSettingsScreen extends ConsumerStatefulWidget {
  const ChatThemeSettingsScreen({super.key});

  @override
  ConsumerState<ChatThemeSettingsScreen> createState() =>
      _ChatThemeSettingsScreenState();
}

class _ChatThemeSettingsScreenState
    extends ConsumerState<ChatThemeSettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await ref.read(chatThemeProvider.notifier).setWallpaper(
            WallpaperType.customImage,
            value: image.path,
          );
      if (mounted) {
        MekaarSnackbar.success(
          context,
          'Gambar galeri berhasil dipasang sebagai wallpaper!',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(chatThemeProvider);

    return MekaarScaffold(
      flat: true,
      appBar: const CustomAppBar(
        title: 'Tema & Wallpaper Chat',
      ),
      body: themeState.when(
        loading: () => const MekaarStateView(
          pose: MikaPose.pin,
          title: 'Memuat Tema Chat',
          message: 'Sedang mengambil pengaturan tema & wallpaper Anda...',
        ),
        error: (err, _) => MekaarStateView(
          pose: MikaPose.neutral,
          title: 'Gagal Memuat Tema Chat',
          message: err.toString(),
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(chatThemeProvider),
        ),
        data: (chatPref) => _buildContent(context, chatPref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChatThemePreference chatPref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Live Chat Playground Header (Paling Atas) ──
          _buildChatPlaygroundHeader(context, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 2. Kontrol Dropdown Pemilihan Tema ──
          _buildPresetDropdown(context, ref, chatPref),
          const SizedBox(height: MekaarSpacing.md),

          _buildWallpaperCanvasDropdown(context, ref, chatPref),
          const SizedBox(height: MekaarSpacing.md),

          _buildBubbleStyleDropdown(context, ref, chatPref),
          const SizedBox(height: MekaarSpacing.md),

          _buildBubbleColorCustomizer(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xxl),

          // ── 3. Bagian Paling Bawah (Wallpaper Galeri, Ukuran Teks & Reset) ──
          Text(
            'OPSI WALLPAPER & UKURAN TEKS',
            style: MekaarTypography.overline,
          ),
          const SizedBox(height: MekaarSpacing.sm),

          _buildBottomOptionsCard(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xxl),
        ],
      ),
    );
  }

  /// Live Chat Playground Header yang menampilkan simulasi percakapan nyata secara real-time.
  Widget _buildChatPlaygroundHeader(
      BuildContext context, ChatThemePreference pref) {
    final outgoingSpec =
        ChatPresetResolver.getBubbleSpec(pref, context, isMe: true);
    final incomingSpec =
        ChatPresetResolver.getBubbleSpec(pref, context, isMe: false);
    final roomThemeSpec =
        ChatPresetResolver.getRoomThemeSpec(pref, context);
    final fontSize = 14.0 * pref.textScale;

    return CustomCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        child: SizedBox(
          height: 250,
          child: Stack(
            children: [
              ChatPresetResolver.buildWallpaper(pref, context),
              // Mini Header Preview
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: roomThemeSpec.glassBackgroundColor ?? Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: roomThemeSpec.glassBorder ??
                        Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(SolarIconsOutline.arrowLeft, size: 14, color: roomThemeSpec.iconColor),
                      const SizedBox(width: 6),
                      Text(
                        'Pratinjau Tema',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: roomThemeSpec.textColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(SolarIconsOutline.phone, size: 14, color: roomThemeSpec.primaryAccentColor),
                      const SizedBox(width: 8),
                      Icon(SolarIconsOutline.menuDots, size: 14, color: roomThemeSpec.primaryAccentColor),
                    ],
                  ),
                ),
              ),
              // Bubbles
              Padding(
                padding: const EdgeInsets.only(top: 44, bottom: 44, left: 12, right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pesan Masuk
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: incomingSpec.backgroundColor,
                          gradient: incomingSpec.gradient,
                          borderRadius: incomingSpec.borderRadius,
                          border: incomingSpec.border,
                          boxShadow: incomingSpec.boxShadow,
                        ),
                        child: Text(
                          'Halo! Apakah lokasi Anda aman?',
                          style: incomingSpec.textStyle
                              .copyWith(fontSize: fontSize),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Pesan Keluar
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: outgoingSpec.backgroundColor,
                          gradient: outgoingSpec.gradient,
                          borderRadius: outgoingSpec.borderRadius,
                          border: outgoingSpec.border,
                          boxShadow: outgoingSpec.boxShadow,
                        ),
                        child: Text(
                          'Aman! Fitur rute perjalanan sedang aktif. 🚀',
                          style: outgoingSpec.textStyle
                              .copyWith(fontSize: fontSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Mini Composer Preview
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: roomThemeSpec.glassBackgroundColor ?? Colors.white.withValues(alpha: 0.15),
                        border: roomThemeSpec.glassBorder ?? Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Icon(SolarIconsOutline.paperclip, size: 14, color: roomThemeSpec.secondaryAccentColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: roomThemeSpec.glassBackgroundColor ?? Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: roomThemeSpec.glassBorder ?? Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ketik pesan...',
                            style: TextStyle(
                              fontSize: 11,
                              color: roomThemeSpec.subtitleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: roomThemeSpec.primaryAccentColor,
                      ),
                      child: const Icon(SolarIconsOutline.plain, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget Pembantu pembuat Card Dropdown terstruktur
  Widget _buildDropdownSection<T>({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: MekaarTypography.overline),
        const SizedBox(height: MekaarSpacing.xs),
        CustomCard(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.md,
            vertical: 4,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              dropdownColor: MekaarColors.surface2Of(context),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    backgroundColor: iconColor.withValues(alpha: 0.15),
                    radius: 16,
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// 1. Dropdown Preset Utama (1-Klik)
  Widget _buildPresetDropdown(
      BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final presets = [
      (
        title: '🌤 Dynamic Time (Otomatis Waktu)',
        color: MekaarColors.cyan,
        preset: ChatThemePreset.dynamicTime
      ),
      (
        title: '🌌 Neon Dreams (Night Youth)',
        color: const Color(0xFF00F5D4),
        preset: ChatThemePreset.neonDreams
      ),
      (
        title: '🎨 Comic Pop Art',
        color: const Color(0xFFFFD84D),
        preset: ChatThemePreset.comicPopArt
      ),
      (
        title: '🧴 Neumorphism UI',
        color: const Color(0xFF94A3B8),
        preset: ChatThemePreset.neumorphism
      ),
      (
        title: '🔮 Glassmorphism',
        color: const Color(0xFF8B5CF6),
        preset: ChatThemePreset.glassmorphism
      ),
      (
        title: '👾 Pixel Garden 8-Bit',
        color: const Color(0xFF3B567D),
        preset: ChatThemePreset.pixelGarden
      ),
      (
        title: '🍬 Candy Pop (Playful Youth)',
        color: const Color(0xFFFF6B9D),
        preset: ChatThemePreset.candyPop
      ),
      (
        title: '🌅 Retro Wave (Nostalgic Youth)',
        color: const Color(0xFFFF006E),
        preset: ChatThemePreset.retroWave
      ),
      (
        title: '⬛ Mono Vibe (Minimalist Youth)',
        color: const Color(0xFF39FF14),
        preset: ChatThemePreset.monoVibe
      ),
      (
        title: '🌿 Solarpunk Eco',
        color: const Color(0xFF10B981),
        preset: ChatThemePreset.solarpunk
      ),
      (
        title: '🌌 Kunang-kunang',
        color: const Color(0xFFF5C97D),
        preset: ChatThemePreset.fireflyNight
      ),
      (
        title: '📖 Buku Harian',
        color: const Color(0xFF1E3A8A),
        preset: ChatThemePreset.diary
      ),
      (
        title: '🛠️ Kustomisasi Manual',
        color: MekaarColors.yellow,
        preset: ChatThemePreset.custom
      ),
    ];

    return _buildDropdownSection<ChatThemePreset>(
      context: context,
      label: 'PRESET UTAMA (1-KLIK)',
      icon: SolarIconsBold.stars,
      iconColor: MekaarColors.cyan,
      value: pref.preset,
      items: presets.map((p) {
        return DropdownMenuItem<ChatThemePreset>(
          value: p.preset,
          child: Row(
            children: [
              CircleAvatar(backgroundColor: p.color, radius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (newVal) {
        if (newVal != null) {
          notifier.applyPreset(newVal);
        }
      },
    );
  }

  /// 2. Dropdown Preset Canvas (Wallpaper Latar Belakang)
  Widget _buildWallpaperCanvasDropdown(
      BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final wallpapers = [
      (
        WallpaperType.dynamicTime,
        'Dynamic Time (Waktu)',
        SolarIconsBold.clockCircle,
        MekaarColors.cyan
      ),
      (
        WallpaperType.pixelGardenCanvas,
        'Pixel Garden 8-Bit',
        SolarIconsBold.gamepad,
        const Color(0xFF3B567D)
      ),
      (
        WallpaperType.fireflyCanvas,
        'Kunang-Kunang',
        SolarIconsBold.stars,
        const Color(0xFFF5C97D)
      ),
      (
        WallpaperType.diaryRuledPaper,
        'Kertas Garis Buku Harian',
        SolarIconsBold.documentText,
        const Color(0xFF1E3A8A)
      ),
      (
        WallpaperType.retroY2KCanvas,
        'Retro Y2K Teal',
        SolarIconsBold.laptop,
        const Color(0xFF008080)
      ),
      (
        WallpaperType.isometricGrid,
        'Isometric Grid 2.5D',
        SolarIconsBold.box,
        const Color(0xFF3B82F6)
      ),
      (
        WallpaperType.swissGrid,
        'Swiss Grid Minimalist',
        SolarIconsBold.widget,
        const Color(0xFFFF5722)
      ),
      (
        WallpaperType.neonGrid,
        'Neon Cyber Grid',
        SolarIconsBold.bolt,
        const Color(0xFF00F0FF)
      ),
      (
        WallpaperType.comicHalftone,
        'Comic Halftone',
        SolarIconsBold.chatRoundDots,
        const Color(0xFFFFD84D)
      ),
      (
        WallpaperType.solarpunkCanvas,
        'Solarpunk Eco',
        SolarIconsBold.leaf,
        const Color(0xFF10B981)
      ),
      (
        WallpaperType.pattern,
        'Pola Dots Minimalis',
        SolarIconsBold.tuningSquare,
        const Color(0xFF64748B)
      ),
      (
        WallpaperType.gradient,
        'Gradien Soft',
        SolarIconsBold.palette,
        const Color(0xFF8B5CF6)
      ),
      (
        WallpaperType.neumorphicCanvas,
        'Soft Slate Neumorphic',
        SolarIconsBold.boxMinimalistic,
        const Color(0xFF94A3B8)
      ),
      (
        WallpaperType.customImage,
        'Foto Galeri HP (Kustom)',
        SolarIconsBold.galleryAdd,
        MekaarColors.yellow
      ),
    ];

    return _buildDropdownSection<WallpaperType>(
      context: context,
      label: 'PRESET CANVAS WALLPAPER',
      icon: SolarIconsBold.gallery,
      iconColor: const Color(0xFF8B5CF6),
      value: pref.wallpaperType,
      items: wallpapers.map((w) {
        return DropdownMenuItem<WallpaperType>(
          value: w.$1,
          child: Row(
            children: [
              Icon(w.$3, size: 16, color: w.$4),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  w.$2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (newVal) {
        if (newVal != null) {
          if (newVal == WallpaperType.customImage) {
            _pickImageFromGallery();
          } else {
            notifier.setWallpaper(newVal);
          }
        }
      },
    );
  }

  /// 3. Dropdown Gaya Gelembung (Bubble Style)
  Widget _buildBubbleStyleDropdown(
      BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final styles = [
      (ChatBubbleStyle.modernPill, 'Modern Pill (Membulat 20px)'),
      (ChatBubbleStyle.classicRounded, 'Classic Rounded (Klasik 12px)'),
      (ChatBubbleStyle.compactSharp, 'Compact Sharp (Sudut Tajam 4px)'),
      (ChatBubbleStyle.glassmorphism, 'Glassmorphism (Transparan)'),
      (ChatBubbleStyle.playfulOutlined, 'Comic Playful (Border Hitam)'),
      (ChatBubbleStyle.cyberEdge, 'Cyberpunk Edge (Glow Neon)'),
      (ChatBubbleStyle.neumorphicSoft, 'Neumorphic Soft UI (Efek 3D)'),
      (ChatBubbleStyle.pixelGardenStyle, 'Pixel Garden 8-Bit (Siku Piksel)'),
      (ChatBubbleStyle.isometric3D, 'Isometric 2.5D (Extruded 3D)'),
      (ChatBubbleStyle.retroBevel, 'Retro OS Bevel (Windows 95)'),
      (ChatBubbleStyle.swissSquare, 'Swiss Minimalist (Siku 0px)'),
      (ChatBubbleStyle.solarpunkLeaf, 'Solarpunk Leaf (Kelopak Daun)'),
    ];

    return _buildDropdownSection<ChatBubbleStyle>(
      context: context,
      label: 'GAYA GELEMBUNG PESAN',
      icon: SolarIconsBold.chatRoundCheck,
      iconColor: const Color(0xFF10B981),
      value: pref.bubbleStyle,
      items: styles.map((s) {
        return DropdownMenuItem<ChatBubbleStyle>(
          value: s.$1,
          child: Text(
            s.$2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (newVal) {
        if (newVal != null) {
          notifier.setBubbleStyle(newVal);
        }
      },
    );
  }

  /// 4. Kustomisasi Warna Gelembung Pesan (Custom & Gradasi 2-Warna)
  Widget _buildBubbleColorCustomizer(
      BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final outgoingSpec = ChatPresetResolver.getBubbleSpec(
      pref,
      context,
      isMe: true,
    );
    final incomingSpec = ChatPresetResolver.getBubbleSpec(
      pref,
      context,
      isMe: false,
    );

    final quickGradientPresets = [
      (name: 'Sunset', c1: '#FF6B9D', c2: '#FF8E53'),
      (name: 'Ocean', c1: '#00F5D4', c2: '#38BDF8'),
      (name: 'Cyber', c1: '#8338EC', c2: '#00F5D4'),
      (name: 'Mint Fresh', c1: '#4ECDC4', c2: '#55EFC4'),
      (name: 'Lavender', c1: '#A8D8EA', c2: '#FF6B9D'),
      (name: 'Sunshine', c1: '#FFE66D', c2: '#FF7675'),
      (name: 'Mono Lime', c1: '#1A1A1A', c2: '#39FF14'),
      (name: 'Midnight', c1: '#0F172A', c2: '#8B5CF6'),
    ];

    Color parseColor(String hex) {
      final cleaned = hex.replaceAll('#', '').trim();
      final val = int.parse(cleaned, radix: 16);
      return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WARNA GELEMBUNG PESAN', style: MekaarTypography.overline),
        const SizedBox(height: MekaarSpacing.xs),
        CustomCard(
          padding: const EdgeInsets.all(MekaarSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Swatches Pengirim & Penerima
              Row(
                children: [
                  Expanded(
                    child: _buildBubbleSwatchCard(
                      context: context,
                      title: 'Gelembung Saya',
                      subtitle: pref.useCustomBubbleColors
                          ? (pref.outgoingColor2 != null
                              ? 'Gradasi 2 Warna'
                              : 'Warna Kustom')
                          : 'Warna Preset Utama',
                      spec: outgoingSpec,
                      onTap: () => _showColorPickerDialog(
                        context,
                        ref,
                        pref,
                        isOutgoing: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: MekaarSpacing.sm),
                  Expanded(
                    child: _buildBubbleSwatchCard(
                      context: context,
                      title: 'Gelembung Teman',
                      subtitle: pref.useCustomBubbleColors
                          ? (pref.incomingColor2 != null
                              ? 'Gradasi 2 Warna'
                              : 'Warna Kustom')
                          : 'Warna Preset Utama',
                      spec: incomingSpec,
                      onTap: () => _showColorPickerDialog(
                        context,
                        ref,
                        pref,
                        isOutgoing: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MekaarSpacing.md),

              // Preset Gradasi 2-Warna Siap Pakai
              Text(
                'Preset Gradasi 2-Warna Siap Pakai:',
                style: MekaarTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : MekaarColors.textMuted,
                ),
              ),
              const SizedBox(height: MekaarSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickGradientPresets.map((p) {
                    final c1 = parseColor(p.c1);
                    final c2 = parseColor(p.c2);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [c1, c2]),
                          ),
                        ),
                        label: Text(
                          p.name,
                          style: MekaarTypography.caption
                              .copyWith(fontSize: 11),
                        ),
                        onPressed: () {
                          notifier.setCustomOutgoingColors(
                            color1: p.c1,
                            color2: p.c2,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (pref.useCustomBubbleColors) ...[
                const SizedBox(height: MekaarSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => notifier.resetCustomBubbleColors(),
                    icon: const Icon(SolarIconsOutline.restart, size: 14),
                    label: const Text('Kembalikan ke Warna Preset Utama'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Swatch Card Component
  Widget _buildBubbleSwatchCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required ChatBubbleSpec spec,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MekaarColors.surface2Of(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MekaarTypography.labelMD
                  .copyWith(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: MekaarTypography.caption.copyWith(
                color: isDark ? Colors.white60 : MekaarColors.textMuted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 36,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: spec.backgroundColor,
                gradient: spec.gradient,
                borderRadius: BorderRadius.circular(10),
                border: spec.border ??
                    Border.all(color: Colors.white24, width: 1),
                boxShadow: spec.boxShadow,
              ),
              child: Center(
                child: Text(
                  'Klik Ubah',
                  style: spec.textStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog Pemilih Warna Kustom & Gradasi
  void _showColorPickerDialog(
    BuildContext context,
    WidgetRef ref,
    ChatThemePreference pref, {
    required bool isOutgoing,
  }) {
    final notifier = ref.read(chatThemeProvider.notifier);

    const colorSwatches = [
      '#FF6B9D', '#FF8E53', '#00F5D4', '#38BDF8', '#8B5CF6', '#A78BFA',
      '#4ECDC4', '#55EFC4', '#FFE66D', '#FF7675', '#39FF14', '#10B981',
      '#FB7185', '#F59E0B', '#1A1A1A', '#2D2D2D', '#0F172A', '#1E1535',
      '#FFFFFF', '#F5F5F5', '#E2E8F0', '#CBD5E1', '#64748B', '#000000',
    ];

    String initialC1 =
        (isOutgoing ? pref.outgoingColor1 : pref.incomingColor1) ??
            (isOutgoing ? '#FF6B9D' : '#4ECDC4');
    String? initialC2 = isOutgoing ? pref.outgoingColor2 : pref.incomingColor2;

    String selectedC1 = initialC1;
    String? selectedC2 = initialC2;
    bool enableGradient = selectedC2 != null;

    Color parseHex(String hex) {
      final cleaned = hex.replaceAll('#', '').trim();
      final val = int.parse(cleaned, radix: 16);
      return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final c1Color = parseHex(selectedC1);
            final c2Color = (enableGradient && selectedC2 != null)
                ? parseHex(selectedC2!)
                : null;
            final gradient = c2Color != null
                ? LinearGradient(colors: [c1Color, c2Color])
                : null;
            final txtColor = c1Color.computeLuminance() < 0.45
                ? Colors.white
                : const Color(0xFF1A1A1A);

            return AlertDialog(
              backgroundColor: MekaarColors.surface2Of(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: c1Color.withValues(alpha: 0.2),
                    radius: 16,
                    child:
                        Icon(SolarIconsBold.palette, color: c1Color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOutgoing
                          ? 'Warna Gelembung Saya'
                          : 'Warna Gelembung Teman',
                      style:
                          MekaarTypography.headingSM.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mini Live Preview Bubble
                    Container(
                      height: 44,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: c1Color,
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c1Color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Simulasi Pesan MEKAAR 🚀',
                          style: TextStyle(
                            color: txtColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggle Gradasi (2 Warna)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Gunakan Gradasi (2 Warna)',
                        style: MekaarTypography.bodyMD
                            .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      value: enableGradient,
                      onChanged: (val) {
                        setDialogState(() {
                          enableGradient = val;
                          if (val && selectedC2 == null) {
                            selectedC2 = '#FF8E53';
                          }
                        });
                      },
                    ),
                    const Divider(),

                    // Palette Warna 1
                    Text('WARNA 1 (UTAMA):', style: MekaarTypography.overline),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: colorSwatches.map((hex) {
                        final color = parseHex(hex);
                        final isSelected = selectedC1 == hex;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedC1 = hex),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black26,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 4)
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: color.computeLuminance() < 0.45
                                        ? Colors.white
                                        : Colors.black,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    if (enableGradient) ...[
                      const SizedBox(height: 14),
                      Text('WARNA 2 (GRADASI):', style: MekaarTypography.overline),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: colorSwatches.map((hex) {
                          final color = parseHex(hex);
                          final isSelected = selectedC2 == hex;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedC2 = hex),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black26,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: color.withValues(alpha: 0.6),
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: color.computeLuminance() < 0.45
                                          ? Colors.white
                                          : Colors.black,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    if (isOutgoing) {
                      notifier.setCustomOutgoingColors(
                        color1: selectedC1,
                        color2: enableGradient ? selectedC2 : null,
                      );
                    } else {
                      notifier.setCustomIncomingColors(
                        color1: selectedC1,
                        color2: enableGradient ? selectedC2 : null,
                      );
                    }
                  },
                  child: const Text('Simpan Warna'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 5. Kartu Opsi Paling Bawah (Wallpaper Galeri, Slider Ukuran Teks & Tombol Reset)
  Widget _buildBottomOptionsCard(
      BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.xs),
      child: Column(
        children: [
          // A. Pilih Foto dari Galeri HP
          ListTile(
            leading: CircleAvatar(
              backgroundColor: MekaarColors.cyan.withValues(alpha: 0.15),
              radius: 18,
              child: const Icon(
                SolarIconsOutline.galleryAdd,
                color: MekaarColors.cyan,
                size: 18,
              ),
            ),
            title: Text(
              'Pilih Foto dari Galeri HP',
              style: MekaarTypography.bodyMD.copyWith(
                fontWeight: pref.wallpaperType == WallpaperType.customImage
                    ? FontWeight.bold
                    : FontWeight.w600,
              ),
            ),
            trailing: pref.wallpaperType == WallpaperType.customImage
                ? const Icon(
                    SolarIconsBold.checkCircle,
                    color: MekaarColors.cyan,
                    size: 22,
                  )
                : const Icon(SolarIconsOutline.altArrowRight, size: 18),
            onTap: _pickImageFromGallery,
          ),

          const MekaarCardDivider(),

          // B. Ukuran Teks Chat Slider
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.md,
              vertical: MekaarSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ukuran Teks Chat',
                      style: MekaarTypography.bodyMD
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(pref.textScale * 100).toInt()}%',
                      style: MekaarTypography.bodyMD.copyWith(
                        color: MekaarColors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: pref.textScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 5,
                  activeColor: MekaarColors.cyan,
                  onChanged: (val) => notifier.setTextScale(val),
                ),
              ],
            ),
          ),

          const MekaarCardDivider(),

          // C. Reset Pengaturan ke Default
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  MekaarColors.textMutedOf(context).withValues(alpha: 0.15),
              radius: 18,
              child: const Icon(
                SolarIconsOutline.restart,
                color: MekaarColors.textMuted,
                size: 18,
              ),
            ),
            title: Text(
              'Reset ke Waktu Dinamis (Default)',
              style: MekaarTypography.bodyMD
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              notifier.resetToDefault();
              MekaarSnackbar.success(
                context,
                'Tema chat berhasil dikembalikan ke default!',
              );
            },
          ),
        ],
      ),
    );
  }
}
