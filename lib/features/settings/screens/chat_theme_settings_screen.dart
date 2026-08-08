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

/// Layar Kustomisasi Tema Chat: Wallpaper, Gaya Gelembung, Warna & Neon/Comic.
class ChatThemeSettingsScreen extends ConsumerStatefulWidget {
  const ChatThemeSettingsScreen({super.key});

  @override
  ConsumerState<ChatThemeSettingsScreen> createState() => _ChatThemeSettingsScreenState();
}

class _ChatThemeSettingsScreenState extends ConsumerState<ChatThemeSettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await ref.read(chatThemeProvider.notifier).setWallpaper(
            WallpaperType.customImage,
            value: image.path,
          );
      if (mounted) {
        MekaarSnackbar.success(context, 'Gambar galeri berhasil dipasang sebagai wallpaper!');
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
          // ── 1. Live Chat Playground Header ──
          _buildChatPlaygroundHeader(context, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 2. Preset Cepat 1-Klik ──
          Text('PRESET UTAMA (1-KLIK)', style: MekaarTypography.overline),
          const SizedBox(height: MekaarSpacing.sm),
          _buildPresetQuickPicker(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 3. Latar Belakang / Wallpaper ──
          Text('WALLPAPER & LATAR CHAT', style: MekaarTypography.overline),
          const SizedBox(height: MekaarSpacing.sm),
          _buildWallpaperPicker(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 4. Gaya Gelembung (Bubble Style) ──
          Text('GAYA GELEMBUNG PESAN', style: MekaarTypography.overline),
          const SizedBox(height: MekaarSpacing.sm),
          _buildBubbleStylePicker(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 5. Palet Warna Gelembung ──
          Text('WARNA GELEMBUNG PESAN', style: MekaarTypography.overline),
          const SizedBox(height: MekaarSpacing.sm),
          _buildBubbleColorPicker(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xl),

          // ── 6. Skala Ukuran Teks Chat ──
          Text('UKURAN TEKS CHAT', style: MekaarTypography.overline),
          const SizedBox(height: MekaarSpacing.sm),
          _buildTextScalePicker(context, ref, chatPref),

          const SizedBox(height: MekaarSpacing.xxl),
        ],
      ),
    );
  }

  /// Live Chat Playground Header yang menampilkan simulasi percakapan nyata.
  Widget _buildChatPlaygroundHeader(BuildContext context, ChatThemePreference pref) {
    final outgoingSpec = ChatPresetResolver.getBubbleSpec(pref, context, isMe: true);
    final incomingSpec = ChatPresetResolver.getBubbleSpec(pref, context, isMe: false);
    final fontSize = 14.0 * pref.textScale;

    return CustomCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        child: SizedBox(
          height: 230,
          child: Stack(
          children: [
            ChatPresetResolver.buildWallpaper(pref, context),
            Padding(
              padding: const EdgeInsets.all(MekaarSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pesan Masuk
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: incomingSpec.backgroundColor,
                        gradient: incomingSpec.gradient,
                        borderRadius: incomingSpec.borderRadius,
                        border: incomingSpec.border,
                        boxShadow: incomingSpec.boxShadow,
                      ),
                      child: Text(
                        'Halo! Apakah lokasi Anda aman?',
                        style: incomingSpec.textStyle.copyWith(fontSize: fontSize),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pesan Keluar
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: outgoingSpec.backgroundColor,
                        gradient: outgoingSpec.gradient,
                        borderRadius: outgoingSpec.borderRadius,
                        border: outgoingSpec.border,
                        boxShadow: outgoingSpec.boxShadow,
                      ),
                      child: Text(
                        'Aman! Fitur rute perjalanan sedang aktif. 🚀',
                        style: outgoingSpec.textStyle.copyWith(fontSize: fontSize),
                      ),
                    ),
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

  /// Preset Cepat Quick Picker (12 Preset Tema Visual Grid 2-Kolom)
  Widget _buildPresetQuickPicker(BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final presets = [
      (title: '🌤 Dynamic Time', color: MekaarColors.cyan, preset: ChatThemePreset.dynamicTime),
      (title: '⚡ Neon Cyberpunk', color: const Color(0xFF00F0FF), preset: ChatThemePreset.neonCyberpunk),
      (title: '🎨 Comic Pop Art', color: const Color(0xFFFFD84D), preset: ChatThemePreset.comicPopArt),
      (title: '🧴 Neumorphism UI', color: const Color(0xFF94A3B8), preset: ChatThemePreset.neumorphism),
      (title: '🔮 Glassmorphism', color: const Color(0xFF8B5CF6), preset: ChatThemePreset.glassmorphism),
      (title: '👾 Pixel Garden 8-Bit', color: const Color(0xFF3B567D), preset: ChatThemePreset.pixelGarden),
      (title: '📐 Isometric 2.5D', color: const Color(0xFF3B82F6), preset: ChatThemePreset.isometric3d),
      (title: '💾 Retro OS Y2K', color: const Color(0xFF008080), preset: ChatThemePreset.retroY2K),
      (title: '⬛ Swiss Minimalist', color: const Color(0xFFFF5722), preset: ChatThemePreset.swissMinimalist),
      (title: '🌿 Solarpunk Eco', color: const Color(0xFF10B981), preset: ChatThemePreset.solarpunk),
      (title: '🌌 Kunang-kunang', color: const Color(0xFFF5C97D), preset: ChatThemePreset.fireflyNight),
      (title: '📖 Buku Harian', color: const Color(0xFF1E3A8A), preset: ChatThemePreset.diary),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.7,
        crossAxisSpacing: MekaarSpacing.xs,
        mainAxisSpacing: MekaarSpacing.xs,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final item = presets[index];
        final isSelected = pref.preset == item.preset;

        return InkWell(
          onTap: () => notifier.applyPreset(item.preset),
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.sm, vertical: MekaarSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected
                  ? item.color.withValues(alpha: 0.15)
                  : MekaarColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(MekaarRadius.md),
              border: Border.all(
                color: isSelected ? item.color : MekaarColors.dividerOf(context),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: item.color.withValues(alpha: 0.2),
                  radius: 14,
                  child: Icon(SolarIconsBold.stars, color: item.color, size: 14),
                ),
                const SizedBox(width: MekaarSpacing.xs),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MekaarTypography.bodySM.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? item.color : MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(SolarIconsBold.checkCircle, color: item.color, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pemilih Wallpaper Chat
  Widget _buildWallpaperPicker(BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);
    final isCustomImage = pref.wallpaperType == WallpaperType.customImage;

    final presetWallpapers = [
      (WallpaperType.dynamicTime, 'Dynamic Time', SolarIconsBold.clockCircle, MekaarColors.cyan),
      (WallpaperType.pixelGardenCanvas, 'Pixel Garden', SolarIconsBold.gamepad, const Color(0xFF3B567D)),
      (WallpaperType.fireflyCanvas, 'Kunang-Kunang', SolarIconsBold.stars, const Color(0xFFF5C97D)),
      (WallpaperType.diaryRuledPaper, 'Buku Harian', SolarIconsBold.documentText, const Color(0xFF1E3A8A)),
      (WallpaperType.retroY2KCanvas, 'Retro Y2K Teal', SolarIconsBold.laptop, const Color(0xFF008080)),
      (WallpaperType.isometricGrid, 'Isometric Grid', SolarIconsBold.box, const Color(0xFF3B82F6)),
      (WallpaperType.swissGrid, 'Swiss Grid', SolarIconsBold.widget, const Color(0xFF000000)),
      (WallpaperType.neonGrid, 'Neon Cyber', SolarIconsBold.bolt, const Color(0xFF00F0FF)),
      (WallpaperType.comicHalftone, 'Comic Halftone', SolarIconsBold.chatRoundDots, const Color(0xFFFFD84D)),
      (WallpaperType.solarpunkCanvas, 'Solarpunk', SolarIconsBold.leaf, const Color(0xFF10B981)),
      (WallpaperType.pattern, 'Pola Dots', SolarIconsBold.tuningSquare, const Color(0xFF64748B)),
      (WallpaperType.gradient, 'Gradien Soft', SolarIconsBold.palette, const Color(0xFF8B5CF6)),
      (WallpaperType.neumorphicCanvas, 'Soft Slate', SolarIconsBold.boxMinimalistic, const Color(0xFF94A3B8)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomCard(
          padding: const EdgeInsets.all(MekaarSpacing.xs),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: MekaarColors.cyan.withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(SolarIconsOutline.galleryAdd, color: MekaarColors.cyan, size: 18),
                ),
                title: Text(
                  'Pilih Foto dari Galeri HP',
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: isCustomImage ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                trailing: isCustomImage
                    ? const Icon(SolarIconsBold.checkCircle, color: MekaarColors.cyan, size: 22)
                    : const Icon(SolarIconsOutline.altArrowRight, size: 18),
                onTap: _pickImageFromGallery,
              ),
              const MekaarCardDivider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: MekaarColors.textMutedOf(context).withValues(alpha: 0.15),
                  radius: 18,
                  child: const Icon(SolarIconsOutline.restart, color: MekaarColors.textMuted, size: 18),
                ),
                title: Text('Reset ke Waktu Dinamis', style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.w600)),
                onTap: () => notifier.resetToDefault(),
              ),
            ],
          ),
        ),
        const SizedBox(height: MekaarSpacing.md),
        Text('PRESET CANVAS WALLPAPER', style: MekaarTypography.overline),
        const SizedBox(height: MekaarSpacing.xs),
        CustomCard(
          padding: const EdgeInsets.all(MekaarSpacing.xs),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presetWallpapers.map((w) {
                final isSelected = pref.wallpaperType == w.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: Icon(w.$3, size: 16, color: isSelected ? Colors.white : w.$4),
                    label: Text(w.$2),
                    selected: isSelected,
                    selectedColor: w.$4,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : MekaarColors.textPrimaryOf(context),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setWallpaper(w.$1);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Pemilih Gaya Gelembung (Style)
  Widget _buildBubbleStylePicker(BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final styles = [
      (ChatBubbleStyle.modernPill, 'Modern Pill', 'Membulat halus 20px'),
      (ChatBubbleStyle.classicRounded, 'Classic Rounded', 'Klasik 12px'),
      (ChatBubbleStyle.compactSharp, 'Compact Sharp', 'Sudut tajam 4px'),
      (ChatBubbleStyle.glassmorphism, 'Glassmorphism', 'Transparan & border halus'),
      (ChatBubbleStyle.playfulOutlined, 'Comic Playful', 'Border hitam tebal komik'),
      (ChatBubbleStyle.cyberEdge, 'Cyberpunk Edge', 'Border glow neon 6px'),
      (ChatBubbleStyle.neumorphicSoft, 'Neumorphic Soft UI', 'Efek timbul / tenggelam 3D'),
      (ChatBubbleStyle.pixelGardenStyle, 'Pixel Garden 8-Bit', 'Sudut siku piksel & shadow 8-bit'),
      (ChatBubbleStyle.isometric3D, 'Isometric 2.5D', 'Blok 3D extruded'),
      (ChatBubbleStyle.retroBevel, 'Retro OS Bevel', 'Bevel 3D era Windows 95'),
      (ChatBubbleStyle.swissSquare, 'Swiss Minimalist', 'Siku 0px & grid presisi'),
      (ChatBubbleStyle.solarpunkLeaf, 'Solarpunk Leaf', 'Form kelopak daun organik'),
    ];

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.xs),
      child: Column(
        children: styles.map((s) {
          final selected = pref.bubbleStyle == s.$1;
          return ListTile(
            title: Text(s.$2, style: MekaarTypography.bodyMD.copyWith(fontWeight: selected ? FontWeight.bold : FontWeight.w600)),
            trailing: selected ? const Icon(SolarIconsBold.checkCircle, color: MekaarColors.cyan, size: 20) : null,
            onTap: () => notifier.setBubbleStyle(s.$1),
          );
        }).toList(),
      ),
    );
  }

  /// Pemilih Palet Warna Gelembung
  Widget _buildBubbleColorPicker(BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final colors = [
      (ChatBubbleColorPreset.defaultTime, 'Default Time Palette', MekaarColors.cyan),
      (ChatBubbleColorPreset.cyberpunkNeon, 'Cyberpunk (Neon Cyan & Magenta)', const Color(0xFF00F0FF)),
      (ChatBubbleColorPreset.comicPop, 'Comic Pop (Kuning & Hitam)', const Color(0xFFFFD84D)),
      (ChatBubbleColorPreset.neumorphicSoft, 'Neumorphic Soft Slate', const Color(0xFF94A3B8)),
      (ChatBubbleColorPreset.glassmorphismTint, 'Glassmorphism Tint', const Color(0xFF8B5CF6)),
      (ChatBubbleColorPreset.pixelGardenNavy, 'Pixel Garden Bluebloom', const Color(0xFF3B567D)),
      (ChatBubbleColorPreset.isometricBlock, 'Isometric Tech Blue', const Color(0xFF3B82F6)),
      (ChatBubbleColorPreset.retroWin95, 'Retro Win95 Blue & Silver', const Color(0xFF008080)),
      (ChatBubbleColorPreset.swissElectric, 'Swiss Electric Orange', const Color(0xFFFF5722)),
      (ChatBubbleColorPreset.solarpunkSage, 'Solarpunk Sage Green', const Color(0xFF10B981)),
      (ChatBubbleColorPreset.emeraldTeal, 'Emerald Teal (Hijau Segar)', const Color(0xFF10B981)),
      (ChatBubbleColorPreset.purpleDream, 'Purple Dream (Ungu Soft)', const Color(0xFF8B5CF6)),
      (ChatBubbleColorPreset.midnightGold, 'Midnight Gold (Emas Malam)', const Color(0xFFF59E0B)),
      (ChatBubbleColorPreset.roseGold, 'Rose Gold (Merah Muda Soft)', const Color(0xFFFB7185)),
    ];

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.xs),
      child: Column(
        children: colors.map((c) {
          final selected = pref.bubbleColorPreset == c.$1;
          return ListTile(
            leading: CircleAvatar(backgroundColor: c.$3, radius: 12),
            title: Text(c.$2, style: MekaarTypography.bodyMD.copyWith(fontWeight: selected ? FontWeight.bold : FontWeight.w600)),
            trailing: selected ? const Icon(SolarIconsBold.checkCircle, color: MekaarColors.cyan, size: 20) : null,
            onTap: () => notifier.setBubbleColor(c.$1),
          );
        }).toList(),
      ),
    );
  }

  /// Pemilih Skala Ukuran Teks Chat
  Widget _buildTextScalePicker(BuildContext context, WidgetRef ref, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Skala Teks', style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold)),
              Text('${(pref.textScale * 100).toInt()}%', style: MekaarTypography.bodyMD.copyWith(color: MekaarColors.cyan, fontWeight: FontWeight.bold)),
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
    );
  }
}
