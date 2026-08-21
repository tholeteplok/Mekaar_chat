import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/bounce_interactive.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/chat_theme_model.dart';
import '../providers/chat_theme_provider.dart';
import '../widgets/settings_tiles.dart';

/// Layar Kustomisasi Tema dan Wallpaper Chat
/// Didesain 1:1 sesuai spesifikasi design.md & mockup tema_wallpaper_chat_redesign.html.
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
      body: SafeArea(
        child: themeState.when(
          loading: () => const MekaarStateView(
            pose: MikaPose.pin,
            title: 'Memuat Tema Chat',
            message: 'Sedang mengambil pengaturan tema & wallpaper Anda...',
          ),
          error: (err, _) => MekaarStateView(
            pose: MikaPose.huft,
            title: 'Gagal Memuat Tema Chat',
            message: ErrorResolver.resolve(err),
            actionLabel: 'Coba Lagi',
            onAction: () => ref.invalidate(chatThemeProvider),
          ),
          data: (chatPref) => _buildContent(context, chatPref),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChatThemePreference chatPref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = MekaarColors.surfaceOf(context);
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFDCE7F5);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Header Terpusat (SettingsTopBar) ──
        const SettingsTopBar(title: 'Tema & Wallpaper Chat'),

        // ── Content Scrollable ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 2. Kartu Live Preview ──
                _buildLivePreviewCard(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                  textSecondary,
                ),

                const SizedBox(height: 20),

                // ── 3. PRESET UTAMA — 1 KLIK (Border 2px brand.blue) ──
                Text(
                  'PRESET UTAMA — 1 KLIK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildMainPresetCard(
                  context,
                  chatPref,
                  cardBg,
                  textPrimary,
                  textSecondary,
                ),

                const SizedBox(height: 20),

                // ── 4. KUSTOMISASI LANJUTAN (Border 1px standar) ──
                Text(
                  'KUSTOMISASI LANJUTAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Card A: Wallpaper Canvas
                _buildOptionRowCard(
                  context: context,
                  icon: SolarIconsOutline.palette,
                  title: 'Wallpaper canvas',
                  value: _getWallpaperLabel(chatPref.wallpaperType),
                  cardBg: cardBg,
                  borderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showWallpaperPicker(context, chatPref),
                ),

                const SizedBox(height: 8),

                // Card B: Gaya Gelembung Pesan
                _buildOptionRowCard(
                  context: context,
                  icon: SolarIconsOutline.chatRoundCheck,
                  title: 'Gaya gelembung pesan',
                  value: _getBubbleStyleLabel(chatPref.bubbleStyle),
                  cardBg: cardBg,
                  borderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showBubbleStylePicker(context, chatPref),
                ),

                const SizedBox(height: 8),

                // Card C: Warna Gelembung Pesan
                _buildBubbleColorCard(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                  textSecondary,
                ),

                const SizedBox(height: 8),

                // Card D: Pilih Foto dari Galeri
                _buildOptionRowCard(
                  context: context,
                  icon: SolarIconsOutline.gallery,
                  title: 'Pilih foto dari galeri',
                  trailingIcon: SolarIconsOutline.altArrowRight,
                  cardBg: cardBg,
                  borderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: _pickImageFromGallery,
                ),

                const SizedBox(height: 8),

                // Card E: Ukuran Teks Chat Slider
                _buildTextScaleCard(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                ),

                const SizedBox(height: 20),

                // ── 5. Reset ke Mekaar (Default) ──
                Center(
                  child: InkWell(
                    onTap: () {
                      ref.read(chatThemeProvider.notifier).resetToDefault();
                      MekaarSnackbar.success(
                        context,
                        'Tema chat berhasil dikembalikan ke default!',
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SolarIconsOutline.restart,
                            size: 15,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reset ke Mekaar (default)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ── 2. Kartu Live Preview ──
  Widget _buildLivePreviewCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final outgoingSpec =
        ChatPresetResolver.getBubbleSpec(pref, context, isMe: true);
    final incomingSpec =
        ChatPresetResolver.getBubbleSpec(pref, context, isMe: false);
    final roomThemeSpec =
        ChatPresetResolver.getRoomThemeSpec(pref, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Mini Header Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      SolarIconsOutline.arrowLeft,
                      size: 16,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pratinjau tema',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      SolarIconsOutline.phone,
                      size: 16,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 12),
                    const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(
                        SolarIconsOutline.menuDots,
                        size: 16,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Wallpaper Canvas Preview Box
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ChatPresetResolver.buildWallpaper(pref, context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Pesan Masuk
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: incomingSpec.backgroundColor,
                              gradient: incomingSpec.gradient,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                                bottomLeft: Radius.circular(6),
                              ),
                              border: incomingSpec.border ??
                                  Border.all(color: borderColor, width: 1),
                              boxShadow: incomingSpec.boxShadow,
                            ),
                            child: Text(
                              'Halo! Apakah lokasi kamu aman?',
                              style: incomingSpec.textStyle.copyWith(
                                fontSize: 13 * pref.textScale,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Pesan Keluar
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: outgoingSpec.backgroundColor,
                              gradient: outgoingSpec.gradient,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(6),
                              ),
                              border: outgoingSpec.border,
                              boxShadow: outgoingSpec.boxShadow,
                            ),
                            child: Text(
                              'Aman, fitur rute perjalanan sedang aktif.',
                              style: outgoingSpec.textStyle.copyWith(
                                fontSize: 13 * pref.textScale,
                              ),
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

          // Mini Composer Input Bar
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(
                  SolarIconsOutline.paperclip,
                  size: 16,
                  color: textPrimary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2638)
                          : const Color(0xFFE8F4FC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ketik pesan…',
                      style: TextStyle(
                        fontSize: 12,
                        color: textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roomThemeSpec.primaryAccentColor,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.plain,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ── 3. PRESET UTAMA (Single Accent 2px brand.blue Border) ──
  Widget _buildMainPresetCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isMekaar = pref.preset == ChatThemePreset.mekaar;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _showPresetPicker(context, pref),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue, width: 2.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF1B2E4B)
                    : const Color(0xFFE8F4FC),
              ),
              child: const Center(
                child: Icon(
                  SolarIconsBold.stars,
                  size: 16,
                  color: AppColors.blue,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPresetLabel(pref.preset),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isMekaar
                        ? 'Default — senada dengan Core'
                        : 'Preset tema aktif',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              SolarIconsOutline.altArrowDown,
              size: 16,
              color: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// ── Row Card Generic untuk Kustomisasi Lanjutan ──
  Widget _buildOptionRowCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? value,
    IconData trailingIcon = SolarIconsOutline.altArrowDown,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              trailingIcon,
              size: 14,
              color: textSecondary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// ── Card Warna Gelembung Pesan ──
  Widget _buildBubbleColorCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(chatThemeProvider.notifier);

    final quickGradients = [
      (name: 'Sunset', c1: '#FF5D5D', c2: '#FBBF24'),
      (name: 'Ocean', c1: '#2DD4BF', c2: '#38BDF8'),
      (name: 'Cyber', c1: '#7F77DD', c2: '#136CFC'),
      (name: 'Mint Fresh', c1: '#4ECDC4', c2: '#55EFC4'),
      (name: 'Rose Gold', c1: '#FB7185', c2: '#F59E0B'),
      (name: 'Midnight', c1: '#0F172A', c2: '#8B5CF6'),
    ];

    Color parseColor(String hex) {
      final cleaned = hex.replaceAll('#', '').trim();
      final val = int.parse(cleaned, radix: 16);
      return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Warna gelembung pesan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // 2 Sub-cards (Gelembung saya & Gelembung teman)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gelembung saya',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showColorPickerDialog(
                          context,
                          pref,
                          isOutgoing: true,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: pref.useCustomBubbleColors
                                ? AppColors.blue
                                : (isDark
                                    ? const Color(0xFF1E2638)
                                    : const Color(0xFFE8F4FC)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ubah',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pref.useCustomBubbleColors
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppColors.blue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gelembung teman',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showColorPickerDialog(
                          context,
                          pref,
                          isOutgoing: false,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2638)
                                : const Color(0xFFE8F4FC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ubah',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Preset gradasi siap pakai',
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Gradation Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickGradients.map((g) {
                final c1 = parseColor(g.c1);
                final c2 = parseColor(g.c2);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      notifier.setCustomOutgoingColors(
                        color1: g.c1,
                        color2: g.c2,
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [c1, c2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Card Ukuran Teks Chat ──
  Widget _buildTextScaleCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);
    final percentage = (pref.textScale * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ukuran teks chat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.blue,
              inactiveTrackColor: AppColors.blue.withValues(alpha: 0.15),
              thumbColor: AppColors.blue,
              overlayColor: AppColors.blue.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider(
              value: pref.textScale.clamp(0.8, 1.4),
              min: 0.8,
              max: 1.4,
              divisions: 6,
              onChanged: (val) => notifier.setTextScale(val),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── MODAL PICKERS (PRESET, WALLPAPER, BUBBLE STYLE, COLOR)
  // ══════════════════════════════════════════════════════════════════════════

  void _showPresetPicker(BuildContext context, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final presets = [
      (
        title: 'Mekaar (clean theme)',
        subtitle: 'Default — senada dengan Core',
        color: AppColors.blue,
        preset: ChatThemePreset.mekaar,
      ),
      (
        title: 'Neon Dreams',
        subtitle: 'Night Youth neon edge & dark glow',
        color: const Color(0xFF00F5D4),
        preset: ChatThemePreset.neonDreams,
      ),
      (
        title: 'Comic Pop Art',
        subtitle: 'Playful halftone & bold outline',
        color: const Color(0xFFFFD84D),
        preset: ChatThemePreset.comicPopArt,
      ),
      (
        title: 'Neumorphism UI',
        subtitle: 'Soft slate 3D extruded surface',
        color: const Color(0xFF94A3B8),
        preset: ChatThemePreset.neumorphism,
      ),
      (
        title: 'Glassmorphism',
        subtitle: 'Frosted purple tint transparan',
        color: const Color(0xFF8B5CF6),
        preset: ChatThemePreset.glassmorphism,
      ),
      (
        title: 'Pixel Garden 8-Bit',
        subtitle: 'Siku piksel retro arcade',
        color: const Color(0xFF3B567D),
        preset: ChatThemePreset.pixelGarden,
      ),
      (
        title: 'Candy Pop',
        subtitle: 'Playful pink & mint isometric',
        color: const Color(0xFFFF6B9D),
        preset: ChatThemePreset.candyPop,
      ),
      (
        title: 'Retro Wave',
        subtitle: 'Windows 95 nostalgic bevel',
        color: const Color(0xFFFF006E),
        preset: ChatThemePreset.retroWave,
      ),
      (
        title: 'Mono Vibe',
        subtitle: 'Minimalist lime text on black',
        color: const Color(0xFF39FF14),
        preset: ChatThemePreset.monoVibe,
      ),
      (
        title: 'Solarpunk Eco',
        subtitle: 'Kelopak daun hijau organik',
        color: const Color(0xFF10B981),
        preset: ChatThemePreset.solarpunk,
      ),
      (
        title: 'Kunang-kunang (Firefly)',
        subtitle: 'Amber slow glow malam hari',
        color: const Color(0xFFF5C97D),
        preset: ChatThemePreset.fireflyNight,
      ),
      (
        title: 'Buku Harian (Diary)',
        subtitle: 'Tulisan tangan & stempel tinta',
        color: const Color(0xFF1E3A8A),
        preset: ChatThemePreset.diary,
      ),
    ];

    MekaarBottomSheet.show(
      context: context,
      title: 'Pilih Preset Utama',
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final brandAccent = MekaarColors.accentOf(context);

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: presets.map((item) {
              final isSelected = pref.preset == item.preset;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: BounceInteractive(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(ctx);
                    notifier.applyPreset(item.preset);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brandAccent.withValues(alpha: isDark ? 0.16 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? brandAccent.withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: item.color,
                          radius: 12,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected
                                      ? brandAccent
                                      : MekaarColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: MekaarTypography.caption.copyWith(
                                  color: MekaarColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            SolarIconsBold.checkCircle,
                            color: brandAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showWallpaperPicker(BuildContext context, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final wallpapers = [
      (WallpaperType.solidColor, 'Mekaar Clean Canvas', SolarIconsBold.palette2, AppColors.blue),
      (WallpaperType.pixelGardenCanvas, 'Pixel Garden 8-Bit', SolarIconsBold.gamepad, const Color(0xFF3B567D)),
      (WallpaperType.fireflyCanvas, 'Kunang-Kunang', SolarIconsBold.stars, const Color(0xFFF5C97D)),
      (WallpaperType.diaryRuledPaper, 'Kertas Garis Buku Harian', SolarIconsBold.documentText, const Color(0xFF1E3A8A)),
      (WallpaperType.retroY2KCanvas, 'Retro Y2K Teal', SolarIconsBold.laptop, const Color(0xFF008080)),
      (WallpaperType.isometricGrid, 'Isometric Grid 2.5D', SolarIconsBold.box, const Color(0xFF3B82F6)),
      (WallpaperType.swissGrid, 'Swiss Grid Minimalist', SolarIconsBold.widget, const Color(0xFFFF5722)),
      (WallpaperType.neonGrid, 'Neon Cyber Grid', SolarIconsBold.bolt, const Color(0xFF00F0FF)),
      (WallpaperType.comicHalftone, 'Comic Halftone', SolarIconsBold.chatRoundDots, const Color(0xFFFFD84D)),
      (WallpaperType.solarpunkCanvas, 'Solarpunk Eco', SolarIconsBold.leaf, const Color(0xFF10B981)),
      (WallpaperType.pattern, 'Pola Dots Minimalis', SolarIconsBold.tuningSquare, const Color(0xFF64748B)),
      (WallpaperType.gradient, 'Gradien Soft', SolarIconsBold.palette, const Color(0xFF8B5CF6)),
      (WallpaperType.neumorphicCanvas, 'Soft Slate Neumorphic', SolarIconsBold.boxMinimalistic, const Color(0xFF94A3B8)),
    ];

    MekaarBottomSheet.show(
      context: context,
      title: 'Pilih Wallpaper Canvas',
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final brandAccent = MekaarColors.accentOf(context);

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: wallpapers.map((item) {
              final isSelected = pref.wallpaperType == item.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: BounceInteractive(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(ctx);
                    notifier.setWallpaper(item.$1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brandAccent.withValues(alpha: isDark ? 0.16 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? brandAccent.withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$3, color: item.$4, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? brandAccent
                                  : MekaarColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            SolarIconsBold.checkCircle,
                            color: brandAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showBubbleStylePicker(BuildContext context, ChatThemePreference pref) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final styles = [
      (ChatBubbleStyle.modernPill, 'Modern Pill', 'Membulat halus 20px'),
      (ChatBubbleStyle.classicRounded, 'Classic Rounded', 'Klasik rounded 12px'),
      (ChatBubbleStyle.compactSharp, 'Compact Sharp', 'Sudut tajam 4px'),
      (ChatBubbleStyle.glassmorphism, 'Glassmorphism', 'Transparan ber-border kaca'),
      (ChatBubbleStyle.playfulOutlined, 'Comic Playful', 'Border hitam pop art'),
      (ChatBubbleStyle.cyberEdge, 'Cyberpunk Edge', 'Glow neon border tegas'),
      (ChatBubbleStyle.neumorphicSoft, 'Neumorphic Soft', 'Efek timbul 3D lembut'),
      (ChatBubbleStyle.pixelGardenStyle, 'Pixel Garden 8-Bit', 'Siku piksel arcade'),
      (ChatBubbleStyle.isometric3D, 'Isometric 2.5D', 'Extruded blok 3D'),
      (ChatBubbleStyle.retroBevel, 'Retro OS Bevel', 'Bevel Windows 95'),
      (ChatBubbleStyle.swissSquare, 'Swiss Minimalist', 'Siku tegak 0px'),
      (ChatBubbleStyle.solarpunkLeaf, 'Solarpunk Leaf', 'Kelopak daun melengkung'),
    ];

    MekaarBottomSheet.show(
      context: context,
      title: 'Pilih Gaya Gelembung',
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final brandAccent = MekaarColors.accentOf(context);

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: styles.map((item) {
              final isSelected = pref.bubbleStyle == item.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: BounceInteractive(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(ctx);
                    notifier.setBubbleStyle(item.$1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brandAccent.withValues(alpha: isDark ? 0.16 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? brandAccent.withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected
                                      ? brandAccent
                                      : MekaarColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                style: MekaarTypography.caption.copyWith(
                                  color: MekaarColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            SolarIconsBold.checkCircle,
                            color: brandAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    ChatThemePreference pref, {
    required bool isOutgoing,
  }) {
    final notifier = ref.read(chatThemeProvider.notifier);

    const colorSwatches = [
      '#FF5D5D', '#FF8E53', '#FBBF24', '#2DD4BF', '#38BDF8', '#136CFC',
      '#7F77DD', '#8B5CF6', '#4ECDC4', '#55EFC4', '#FFE66D', '#10B981',
      '#FB7185', '#F59E0B', '#1A1A1A', '#2D2D2D', '#0F172A', '#1E1535',
      '#FFFFFF', '#F5F5F5', '#E2E8F0', '#CBD5E1', '#64748B', '#000000',
    ];

    String initialC1 =
        (isOutgoing ? pref.outgoingColor1 : pref.incomingColor1) ??
            (isOutgoing ? '#136CFC' : '#E8F4FC');
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
              backgroundColor: MekaarColors.surfaceOf(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: c1Color.withValues(alpha: 0.2),
                    radius: 16,
                    child: Icon(SolarIconsBold.palette, color: c1Color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOutgoing
                          ? 'Warna Gelembung Saya'
                          : 'Warna Gelembung Teman',
                      style: MekaarTypography.headingSM.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mini Bubble Simulation
                    Container(
                      height: 44,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Gunakan Gradasi (2 Warna)',
                        style: MekaarTypography.bodyMD.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      value: enableGradient,
                      onChanged: (val) {
                        setDialogState(() {
                          enableGradient = val;
                          if (val && selectedC2 == null) {
                            selectedC2 = '#7F77DD';
                          }
                        });
                      },
                    ),
                    const Divider(),

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
                                        blurRadius: 4,
                                      )
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

  // ══════════════════════════════════════════════════════════════════════════
  // ── HELPERS LABEL STRINGS
  // ══════════════════════════════════════════════════════════════════════════

  String _getPresetLabel(ChatThemePreset preset) {
    switch (preset) {
      case ChatThemePreset.mekaar:
      case ChatThemePreset.dynamicTime:
        return 'Mekaar (clean theme)';
      case ChatThemePreset.neonDreams:
      case ChatThemePreset.neonCyberpunk:
        return 'Neon Dreams';
      case ChatThemePreset.comicPopArt:
        return 'Comic Pop Art';
      case ChatThemePreset.neumorphism:
        return 'Neumorphism UI';
      case ChatThemePreset.glassmorphism:
        return 'Glassmorphism';
      case ChatThemePreset.pixelGarden:
        return 'Pixel Garden 8-Bit';
      case ChatThemePreset.candyPop:
      case ChatThemePreset.isometric3d:
        return 'Candy Pop';
      case ChatThemePreset.retroWave:
      case ChatThemePreset.retroY2K:
        return 'Retro Wave';
      case ChatThemePreset.monoVibe:
      case ChatThemePreset.swissMinimalist:
        return 'Mono Vibe';
      case ChatThemePreset.solarpunk:
        return 'Solarpunk Eco';
      case ChatThemePreset.fireflyNight:
        return 'Kunang-kunang';
      case ChatThemePreset.diary:
        return 'Buku Harian';
      case ChatThemePreset.custom:
        return 'Kustomisasi Manual';
    }
  }

  String _getWallpaperLabel(WallpaperType type) {
    switch (type) {
      case WallpaperType.solidColor:
      case WallpaperType.dynamicTime:
        return 'Mekaar clean canvas';
      case WallpaperType.pixelGardenCanvas:
        return 'Pixel Garden 8-Bit';
      case WallpaperType.fireflyCanvas:
        return 'Kunang-Kunang';
      case WallpaperType.diaryRuledPaper:
        return 'Kertas Garis Buku Harian';
      case WallpaperType.retroY2KCanvas:
        return 'Retro Y2K Teal';
      case WallpaperType.isometricGrid:
        return 'Isometric Grid 2.5D';
      case WallpaperType.swissGrid:
        return 'Swiss Grid';
      case WallpaperType.neonGrid:
        return 'Neon Cyber Grid';
      case WallpaperType.comicHalftone:
        return 'Comic Halftone';
      case WallpaperType.solarpunkCanvas:
        return 'Solarpunk Eco';
      case WallpaperType.pattern:
        return 'Pola Dots';
      case WallpaperType.gradient:
        return 'Gradien Soft';
      case WallpaperType.neumorphicCanvas:
        return 'Soft Slate Neumorphic';
      case WallpaperType.customImage:
        return 'Foto Galeri';
    }
  }

  String _getBubbleStyleLabel(ChatBubbleStyle style) {
    switch (style) {
      case ChatBubbleStyle.modernPill:
        return 'Modern pill';
      case ChatBubbleStyle.classicRounded:
        return 'Classic rounded';
      case ChatBubbleStyle.compactSharp:
        return 'Compact sharp';
      case ChatBubbleStyle.glassmorphism:
        return 'Glassmorphism';
      case ChatBubbleStyle.playfulOutlined:
        return 'Comic playful';
      case ChatBubbleStyle.cyberEdge:
        return 'Cyberpunk edge';
      case ChatBubbleStyle.neumorphicSoft:
        return 'Neumorphic soft';
      case ChatBubbleStyle.pixelGardenStyle:
        return 'Pixel garden';
      case ChatBubbleStyle.isometric3D:
        return 'Isometric 3D';
      case ChatBubbleStyle.retroBevel:
        return 'Retro bevel';
      case ChatBubbleStyle.swissSquare:
        return 'Swiss square';
      case ChatBubbleStyle.solarpunkLeaf:
        return 'Solarpunk leaf';
      case ChatBubbleStyle.fireflyAmber:
        return 'Firefly amber';
      case ChatBubbleStyle.diaryHandwriting:
        return 'Buku harian';
    }
  }
}
