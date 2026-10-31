import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bubbles/themed_bubble_container.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_section_header.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/chat_theme_model.dart';
import '../providers/chat_theme_provider.dart';
import '../widgets/settings_tiles.dart';

/// Swatch preset tema chat & wallpaper — data produk (identitas visual
/// tiap preset), BUKAN token UI adaptif. Jangan dipakai untuk chrome UI.
const Color _kSwatchMekaar = AppColors.blue;
const Color _kSwatchComic = Color(0xFFFFD84D);
const Color _kSwatchNeuro = Color(0xFF94A3B8);
const Color _kSwatchMecha = Color(0xFF00F0FF);
const Color _kSwatchPixel = Color(0xFF3B567D);
const Color _kSwatchCandy = Color(0xFFFF6B9D);
const Color _kSwatchEco = Color(0xFF10B981);
const Color _kSwatchCustom = Color(0xFF8B5CF6);

/// Daftar warna swatch palet inline cepat (24 pilihan warna).
const List<String> _kColorSwatches = [
  '#136CFC',
  '#38BDF8',
  '#2DD4BF',
  '#10B981',
  '#4ECDC4',
  '#55EFC4',
  '#FBBF24',
  '#F59E0B',
  '#FF8E53',
  '#FF5D5D',
  '#FB7185',
  '#FF6B9D',
  '#8B5CF6',
  '#7F77DD',
  '#0F172A',
  '#1E1535',
  '#2D2D2D',
  '#64748B',
  '#94A3B8',
  '#CBD5E1',
  '#E2E8F0',
  '#F1F5F9',
  '#FFFFFF',
  '#000000',
];

/// Daftar gradasi cepat siap pakai untuk Pesan Keluar (Saya).
const _kOutgoingGradients = [
  (name: 'Sunset', c1: '#FF5D5D', c2: '#FBBF24'),
  (name: 'Ocean', c1: '#2DD4BF', c2: '#38BDF8'),
  (name: 'Cyber', c1: '#7F77DD', c2: '#136CFC'),
  (name: 'Mint Fresh', c1: '#4ECDC4', c2: '#55EFC4'),
  (name: 'Rose Gold', c1: '#FB7185', c2: '#F59E0B'),
  (name: 'Midnight', c1: '#0F172A', c2: '#8B5CF6'),
];

/// Daftar gradasi cepat siap pakai untuk Pesan Masuk (Teman).
const _kIncomingGradients = [
  (name: 'Soft Slate', c1: '#E2E8F0', c2: '#CBD5E1'),
  (name: 'Cloud Sky', c1: '#E0F2FE', c2: '#BAE6FD'),
  (name: 'Lavender Mist', c1: '#F3E8FF', c2: '#E9D5FF'),
  (name: 'Frosted Mint', c1: '#E6FFFA', c2: '#B2F5EA'),
  (name: 'Warm Peach', c1: '#FFEDD5', c2: '#FED7AA'),
  (name: 'Deep Cosmic', c1: '#1E293B', c2: '#334155'),
];

/// Layar Kustomisasi Tema dan Wallpaper Chat
/// Menerapkan Zero-Occlusion Inline Manipulation:
/// Semua penyesuaian (Preset, Bentuk Bubble, Warna, dan Wallpaper) dilakukan
/// secara inline tanpa dialog modal atau bottomsheet yang menutupi live preview.
class ChatThemeSettingsScreen extends ConsumerStatefulWidget {
  const ChatThemeSettingsScreen({super.key});

  @override
  ConsumerState<ChatThemeSettingsScreen> createState() =>
      _ChatThemeSettingsScreenState();
}

class _ChatThemeSettingsScreenState
    extends ConsumerState<ChatThemeSettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _presetScrollController = ScrollController();

  int _activePresetScrollIndex = 0;
  int _selectedTabIndex = 0; // 0: Bentuk Gelembung, 1: Warna, 2: Wallpaper
  bool _isOutgoingColorTab =
      true; // Sub-tab warna: true = Keluar (Saya), false = Masuk (Teman)
  bool _enableGradient = false;

  @override
  void initState() {
    super.initState();
    _presetScrollController.addListener(_onPresetScroll);
  }

  void _onPresetScroll() {
    if (!_presetScrollController.hasClients) return;
    const cardExtent = 116.0; // 108px width + 8px gap
    final index = (_presetScrollController.offset / cardExtent).round().clamp(
      0,
      7,
    );
    if (index != _activePresetScrollIndex) {
      setState(() {
        _activePresetScrollIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _presetScrollController.removeListener(_onPresetScroll);
    _presetScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await ref
          .read(chatThemeProvider.notifier)
          .setWallpaper(WallpaperType.customImage, value: image.path);
      if (mounted) {
        MekaarSnackbar.success(
          context,
          'Gambar galeri berhasil dipasang sebagai wallpaper!',
        );
      }
    }
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final val = int.parse(cleaned, radix: 16);
    return Color(cleaned.length == 6 ? 0xFF000000 | val : val);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(chatThemeProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: themeState.when(
          loading: () => const MekaarStateView(
            pose: MikaPose.neutral,
            title: 'Memuat Tema Chat',
            message: 'Sedang mengambil pengaturan tema & wallpaper Anda...',
          ),
          error: (err, _) => MekaarStateView(
            pose: ErrorResolver.resolvePose(err),
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
    final cardBg = MekaarColors.surfaceOf(context);
    final cardBorderColor = MekaarColors.borderOf(context);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Header Terpusat (SettingsTopBar) ──
        const SettingsTopBar(title: 'Tema & Wallpaper Chat'),

        // ── 2. Kartu Live Preview Statis (Pinned di Atas — Zero Occlusion) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: _buildLivePreviewCard(
            context,
            chatPref,
            cardBg,
            cardBorderColor,
            textPrimary,
            textSecondary,
          ),
        ),

        // ── 3. Content Scrollable di Bawah Live Preview ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── PRESET UTAMA — 1 KLIK ──
                MekaarSectionHeader(
                  title: 'Preset Tema',
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
                  trailing: Text(
                    'Geser & pilih',
                    style: MekaarTypography.caption.copyWith(
                      fontSize: 11,
                      color: textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Carousel 8 Kartu Preset Horizontal
                _buildPresetCarousel(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 8),

                // Dot Indikator Carousel Penanda Posisi
                _buildCarouselDotIndicators(textSecondary),
                const SizedBox(height: 18),

                // ── KUSTOMISASI LANJUTAN (Segmented Control Terpusat) ──
                const MekaarSectionHeader(
                  title: 'Kustomisasi Lanjutan',
                  padding: EdgeInsets.only(left: 4, top: 12, bottom: 8),
                ),

                // Segmented Control Terpusat (MekaarSlidingSegmentBar)
                MekaarSlidingSegmentBar(
                  margin: EdgeInsets.zero,
                  height: 42,
                  tabs: const ['Bentuk', 'Warna', 'Wallpaper'],
                  selectedIndex: _selectedTabIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Panel Inline Berdasarkan Tab Aktif
                _buildInlineTabContent(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 14),

                // ── Ukuran Teks Chat Slider ──
                _buildTextScaleCard(
                  context,
                  chatPref,
                  cardBg,
                  cardBorderColor,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 18),

                // ── Tombol Reset ke Mekaar (Default) ──
                _buildResetButton(context, textSecondary),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 2. LIVE PREVIEW CARD (PINNED ATAS)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLivePreviewCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
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
    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(pref, context);
    final isDark = MekaarColors.isDarkContext(context);

    final headerIconColor = roomThemeSpec.iconColor;
    final headerTextColor = roomThemeSpec.textColor;
    final headerSubtitleColor = roomThemeSpec.subtitleColor;

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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      SolarIconsOutline.arrowLeft,
                      size: 18,
                      color: headerIconColor,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.blue,
                      ),
                      child: const Center(
                        child: Text(
                          'M',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pratinjau Langsung',
                          style: MekaarTypography.bodyMD.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: headerTextColor,
                          ),
                        ),
                        Text(
                          pref.preset == ChatThemePreset.custom
                              ? 'Kustom Aktif'
                              : 'Online',
                          style: MekaarTypography.caption.copyWith(
                            fontSize: 11,
                            color: headerSubtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      SolarIconsOutline.videocamera,
                      size: 18,
                      color: headerIconColor,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      SolarIconsOutline.phoneRounded,
                      size: 18,
                      color: headerIconColor,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      SolarIconsOutline.menuDots,
                      size: 18,
                      color: headerIconColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Wallpaper Canvas Preview Box
          Container(
            height: 126,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
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
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pesan Masuk
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ThemedBubbleContainer(
                            spec: incomingSpec,
                            isMe: false,
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              'Halo! Lokasimu aman terkendali?',
                              style: incomingSpec.textStyle.copyWith(
                                fontSize: 13 * pref.textScale,
                              ),
                            ),
                          ),
                        ),

                        // Pesan Keluar
                        Align(
                          alignment: Alignment.centerRight,
                          child: ThemedBubbleContainer(
                            spec: outgoingSpec,
                            isMe: true,
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              'Aman! Rute pelindung aktif 🛡️',
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
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? MekaarColors.composerPillDark
                          : MekaarColors.composerPillLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          SolarIconsOutline.smileCircle,
                          size: 17,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ketik pesan…',
                            style: MekaarTypography.bodySM.copyWith(
                              fontSize: 13 * pref.textScale,
                              color: textPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Icon(
                          SolarIconsOutline.paperclip,
                          size: 17,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
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

  // ══════════════════════════════════════════════════════════════════════════
  // ── 3. PRESET CAROUSEL & DOT INDICATORS (8 ITEMS: 7 PRESETS + 1 CUSTOM)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPresetCarousel(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color cardBorderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final presets = [
      (
        title: 'Mekaar Core',
        subtitle: 'Slate clean & swoop',
        color: _kSwatchMekaar,
        preset: ChatThemePreset.mekaar,
        icon: SolarIconsBold.shieldCheck,
      ),
      (
        title: 'Comic Art',
        subtitle: 'Halftone pop & ink',
        color: _kSwatchComic,
        preset: ChatThemePreset.comic,
        icon: SolarIconsBold.chatRoundDots,
      ),
      (
        title: 'Neuro UI',
        subtitle: 'Soft slate 3D deboss',
        color: _kSwatchNeuro,
        preset: ChatThemePreset.neuro,
        icon: SolarIconsBold.boxMinimalistic,
      ),
      (
        title: 'Mecha Style',
        subtitle: 'Chamfer armor tactical',
        color: _kSwatchMecha,
        preset: ChatThemePreset.mecha,
        icon: SolarIconsBold.tuningSquare,
      ),
      (
        title: 'Pixel Craft',
        subtitle: 'Retro arcade voxel',
        color: _kSwatchPixel,
        preset: ChatThemePreset.pixel,
        icon: SolarIconsBold.gamepad,
      ),
      (
        title: 'Candy Pop',
        subtitle: 'Playful pink rounded',
        color: _kSwatchCandy,
        preset: ChatThemePreset.candy,
        icon: SolarIconsBold.heart,
      ),
      (
        title: 'Solar Punk',
        subtitle: 'Ivory nature leaf',
        color: _kSwatchEco,
        preset: ChatThemePreset.eco,
        icon: SolarIconsBold.leaf,
      ),
      (
        title: 'Kustom',
        subtitle: 'Racikan personal',
        color: _kSwatchCustom,
        preset: ChatThemePreset.custom,
        icon: SolarIconsBold.magicStick,
      ),
    ];

    return SizedBox(
      height: 114,
      child: ListView.separated(
        controller: _presetScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = presets[index];
          final isSelected = pref.preset == item.preset;

          return PressableScale(
            onTap: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              notifier.applyPreset(item.preset);
              _presetScrollController.animateTo(
                (index * 116.0).clamp(
                  0.0,
                  _presetScrollController.position.maxScrollExtent,
                ),
                duration: MekaarMotion.counter,
                curve: MekaarMotion.standard,
              );
            },
            child: AnimatedContainer(
              duration: context.motion(MekaarMotion.fast),
              width: 108,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.blue : cardBorderColor,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Icon(item.icon, size: 15, color: item.color),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.blue,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MekaarTypography.labelLG.copyWith(
                          fontSize: 13.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected ? AppColors.blue : textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MekaarTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselDotIndicators(Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final isActive = _activePresetScrollIndex == index;
        return AnimatedContainer(
          duration: context.motion(MekaarMotion.normal),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? AppColors.blue
                : textSecondary.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 4. INLINE TAB PANELS (ZERO OCCLUSION)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInlineTabContent(
    BuildContext context,
    ChatThemePreference chatPref,
    Color cardBg,
    Color cardBorderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildBubbleShapePanel(
          context,
          chatPref,
          cardBg,
          cardBorderColor,
          textPrimary,
          textSecondary,
        );
      case 1:
        return _buildBubbleColorPanel(
          context,
          chatPref,
          cardBg,
          cardBorderColor,
          textPrimary,
          textSecondary,
        );
      case 2:
      default:
        return _buildWallpaperPanel(
          context,
          chatPref,
          cardBg,
          cardBorderColor,
          textPrimary,
          textSecondary,
        );
    }
  }

  // ── TAB 0: BENTUK GELEMBUNG (7 Bentuk Preset Vertikal) ──
  Widget _buildBubbleShapePanel(
    BuildContext context,
    ChatThemePreference chatPref,
    Color cardBg,
    Color cardBorderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final bubbleShapes = [
      (
        style: ChatBubbleStyle.modernPill,
        title: 'Modern Pill (Mekaar Core)',
        desc: 'Membulat halus 20px khas kenyamanan Mekaar Core',
        icon: SolarIconsBold.shieldCheck,
      ),
      (
        style: ChatBubbleStyle.playfulOutlined,
        title: 'Comic Retro Ink',
        desc: 'Border hitam tebal pop-art & ekor gelembung runcing retro',
        icon: SolarIconsBold.chatRoundDots,
      ),
      (
        style: ChatBubbleStyle.neumorphicSoft,
        title: 'Neumorphic Soft (Neuro UI)',
        desc: 'Efek timbul & inset deboss 3D lembut menyatu kanvas',
        icon: SolarIconsBold.boxMinimalistic,
      ),
      (
        style: ChatBubbleStyle.mechaChamfer,
        title: 'Mecha Tactical Armor',
        desc: 'Sudut terpotong chamfer 45° dengan aksen cyber laser tajam',
        icon: SolarIconsBold.tuningSquare,
      ),
      (
        style: ChatBubbleStyle.pixelGardenStyle,
        title: 'Pixel Craft Voxel',
        desc: 'Siku piksel arcade 0px dengan bayangan voxel bertingkat',
        icon: SolarIconsBold.gamepad,
      ),
      (
        style: ChatBubbleStyle.classicRounded,
        title: 'Candy Jelly Rounded',
        desc: 'Bubbly rounded 22px playful, ceria, dan memikat',
        icon: SolarIconsBold.heart,
      ),
      (
        style: ChatBubbleStyle.solarpunkLeaf,
        title: 'Solarpunk Leaf (Solar Punk)',
        desc: 'Kelopak daun melengkung asimetris organik dan menenangkan',
        icon: SolarIconsBold.leaf,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        children: List.generate(bubbleShapes.length, (index) {
          final item = bubbleShapes[index];
          final isSelected = chatPref.bubbleStyle == item.style;
          final isLast = index == bubbleShapes.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  notifier.setBubbleStyle(item.style);
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: isLast ? const Radius.circular(14) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.blue.withValues(alpha: 0.15)
                              : cardBorderColor.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Icon(
                            item.icon,
                            size: 16,
                            color: isSelected ? AppColors.blue : textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: MekaarTypography.bodyMD.copyWith(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.blue
                                    : textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.desc,
                              style: MekaarTypography.caption.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.normal,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          SolarIconsBold.checkCircle,
                          size: 20,
                          color: AppColors.blue,
                        )
                      else
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast) const MekaarCardDivider(indent: 58, endIndent: 14),
            ],
          );
        }),
      ),
    );
  }

  // ── TAB 1: WARNA GELEMBUNG (Inline Palet, Gradasi Keluar & Masuk) ──
  Widget _buildBubbleColorPanel(
    BuildContext context,
    ChatThemePreference chatPref,
    Color cardBg,
    Color cardBorderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final currentOutgoingC1 = chatPref.outgoingColor1 ?? '#136CFC';
    final currentOutgoingC2 = chatPref.outgoingColor2;
    final currentIncomingC1 = chatPref.incomingColor1 ?? '#E2E8F0';
    final currentIncomingC2 = chatPref.incomingColor2;

    final targetC1 = _isOutgoingColorTab
        ? currentOutgoingC1
        : currentIncomingC1;
    final targetC2 = _isOutgoingColorTab
        ? currentOutgoingC2
        : currentIncomingC2;
    final isGradActive = _enableGradient || targetC2 != null;

    final activePresetGradients = _isOutgoingColorTab
        ? _kOutgoingGradients
        : _kIncomingGradients;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Segment Terpusat: Gelembung Saya vs Gelembung Teman
          MekaarSlidingSegmentBar(
            margin: EdgeInsets.zero,
            height: 36,
            tabs: const ['Pesan Saya (Keluar)', 'Pesan Teman (Masuk)'],
            selectedIndex: _isOutgoingColorTab ? 0 : 1,
            onTabSelected: (index) {
              setState(() {
                _isOutgoingColorTab = index == 0;
              });
            },
          ),
          const SizedBox(height: 14),

          // Preset Gradasi Siap Pakai (Tersedia untuk Keluar Maupun Masuk)
          Text(
            _isOutgoingColorTab
                ? 'Preset Gradasi Pesan Saya:'
                : 'Preset Gradasi Pesan Teman:',
            style: MekaarTypography.labelMD.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: activePresetGradients.map((g) {
                final c1 = _parseHex(g.c1);
                final c2 = _parseHex(g.c2);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      setState(() {
                        _enableGradient = true;
                      });
                      if (_isOutgoingColorTab) {
                        notifier.setCustomOutgoingColors(
                          color1: g.c1,
                          color2: g.c2,
                        );
                      } else {
                        notifier.setCustomIncomingColors(
                          color1: g.c1,
                          color2: g.c2,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: cardBorderColor, width: 1),
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
                            style: MekaarTypography.bodySM.copyWith(
                              fontSize: 11.5,
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 14),

          // Switch Aktifkan Gradasi 2 Warna
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gunakan Gradasi 2 Warna',
                style: MekaarTypography.bodyMD.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Switch(
                value: isGradActive,
                activeTrackColor: AppColors.blue.withValues(alpha: 0.5),
                activeThumbColor: AppColors.blue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() {
                    _enableGradient = val;
                  });
                  if (_isOutgoingColorTab) {
                    notifier.setCustomOutgoingColors(
                      color1: targetC1,
                      color2: val ? (targetC2 ?? '#7F77DD') : null,
                    );
                  } else {
                    notifier.setCustomIncomingColors(
                      color1: targetC1,
                      color2: val ? (targetC2 ?? '#94A3B8') : null,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Swatches Warna 1 (Utama)
          Text(
            isGradActive ? 'Warna 1 (Awal):' : 'Pilihan Warna Swatch:',
            style: MekaarTypography.labelMD.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kColorSwatches.map((hex) {
              final color = _parseHex(hex);
              final isSelected = targetC1.toUpperCase() == hex.toUpperCase();

              return GestureDetector(
                onTap: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  if (_isOutgoingColorTab) {
                    notifier.setCustomOutgoingColors(
                      color1: hex,
                      color2: isGradActive ? targetC2 : null,
                    );
                  } else {
                    notifier.setCustomIncomingColors(
                      color1: hex,
                      color2: isGradActive ? targetC2 : null,
                    );
                  }
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.black26,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 5,
                            ),
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

          // Swatches Warna 2 (Gradasi Akhir) jika gradasi aktif
          if (isGradActive) ...[
            const SizedBox(height: 14),
            Text(
              'Warna 2 (Akhir Gradasi):',
              style: MekaarTypography.labelMD.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kColorSwatches.map((hex) {
                final color = _parseHex(hex);
                final isSelected =
                    targetC2 != null &&
                    targetC2.toUpperCase() == hex.toUpperCase();

                return GestureDetector(
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    if (_isOutgoingColorTab) {
                      notifier.setCustomOutgoingColors(
                        color1: targetC1,
                        color2: hex,
                      );
                    } else {
                      notifier.setCustomIncomingColors(
                        color1: targetC1,
                        color2: hex,
                      );
                    }
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.black26,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 5,
                              ),
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

          // Tombol Reset Warna Custom ke Preset
          if (chatPref.useCustomBubbleColors) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  notifier.resetCustomBubbleColors();
                  setState(() {
                    _enableGradient = false;
                  });
                  MekaarSnackbar.success(
                    context,
                    'Warna gelembung dikembalikan ke warna bawaan preset!',
                  );
                },
                icon: const Icon(SolarIconsOutline.restart, size: 14),
                label: Text(
                  'Gunakan Warna Bawaan Preset',
                  style: MekaarTypography.bodySM.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── TAB 2: WALLPAPER (List Vertikal Terpadu — 7 Preset + 1 Galeri HP) ──
  Widget _buildWallpaperPanel(
    BuildContext context,
    ChatThemePreference chatPref,
    Color cardBg,
    Color cardBorderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);

    final wallpapers = [
      (
        type: WallpaperType.solidColor,
        title: 'Mekaar Clean Canvas',
        desc: 'Latar bersih adaptif siang & malam (Default)',
        icon: SolarIconsBold.shieldCheck,
        color: _kSwatchMekaar,
      ),
      (
        type: WallpaperType.comicHalftone,
        title: 'Comic Halftone',
        desc: 'Pola titik halftone pop-art retro bergaris',
        icon: SolarIconsBold.chatRoundDots,
        color: _kSwatchComic,
      ),
      (
        type: WallpaperType.neumorphicCanvas,
        title: 'Neumorphic Slate Canvas',
        desc: 'Tekstur lembut timbul menyatu dengan kanvas',
        icon: SolarIconsBold.boxMinimalistic,
        color: _kSwatchNeuro,
      ),
      (
        type: WallpaperType.mechaBlueprintGrid,
        title: 'Mecha Blueprint Grid',
        desc: 'Kisi blueprint taktis futuristik berpresisi tinggi',
        icon: SolarIconsBold.tuningSquare,
        color: _kSwatchMecha,
      ),
      (
        type: WallpaperType.pixelGardenCanvas,
        title: 'Pixel Craft Voxel Canvas',
        desc: 'Kisi piksel arcade 8-bit retro dengan bayangan voxel',
        icon: SolarIconsBold.gamepad,
        color: _kSwatchPixel,
      ),
      (
        type: WallpaperType.pattern,
        title: 'Pola Candy Polka',
        desc: 'Taburan bintik ceria manis playful',
        icon: SolarIconsBold.heart,
        color: _kSwatchCandy,
      ),
      (
        type: WallpaperType.solarpunkCanvas,
        title: 'Solarpunk Calm Canvas',
        desc: 'Tekstur dedaunan alami bernuansa tenang & ivory',
        icon: SolarIconsBold.leaf,
        color: _kSwatchEco,
      ),
      (
        type: WallpaperType.customImage,
        title: 'Pilih Foto dari Galeri',
        desc: 'Gunakan foto pribadi dari penyimpanan HP sebagai wallpaper',
        icon: SolarIconsBold.gallery,
        color: AppColors.blue,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: Column(
        children: List.generate(wallpapers.length, (index) {
          final item = wallpapers[index];
          final isSelected = chatPref.wallpaperType == item.type;
          final isLast = index == wallpapers.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  if (item.type == WallpaperType.customImage) {
                    _pickImageFromGallery();
                  } else {
                    notifier.setWallpaper(item.type);
                  }
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: isLast ? const Radius.circular(14) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color.withValues(alpha: 0.18),
                        ),
                        child: Center(
                          child: Icon(item.icon, size: 16, color: item.color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: MekaarTypography.bodyMD.copyWith(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.blue
                                    : textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.desc,
                              style: MekaarTypography.caption.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.normal,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          SolarIconsBold.checkCircle,
                          size: 20,
                          color: AppColors.blue,
                        )
                      else
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast) const MekaarCardDivider(indent: 58, endIndent: 14),
            ],
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── 5. UKURAN TEKS SLIDER CARD & RESET BUTTON
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTextScaleCard(
    BuildContext context,
    ChatThemePreference pref,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final notifier = ref.read(chatThemeProvider.notifier);
    final percentage = (pref.textScale * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                'Ukuran Teks Obrolan',
                style: MekaarTypography.bodyMD.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Text(
                '$percentage%',
                style: MekaarTypography.labelLG.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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

  Widget _buildResetButton(BuildContext context, Color textSecondary) {
    return Center(
      child: InkWell(
        onTap: () {
          HapticService.trigger(MekaarHapticIntent.selection);
          ref.read(chatThemeProvider.notifier).resetToDefault();
          setState(() {
            _enableGradient = false;
          });
          MekaarSnackbar.success(
            context,
            'Tema chat berhasil dikembalikan ke default!',
          );
        },
        borderRadius: BorderRadius.circular(MekaarRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(SolarIconsOutline.restart, size: 16, color: textSecondary),
              const SizedBox(width: 8),
              Text(
                'Reset ke Mekaar (default)',
                style: MekaarTypography.bodySM.copyWith(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
