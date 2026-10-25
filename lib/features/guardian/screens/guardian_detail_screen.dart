import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_badge.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/widgets/mekaar_icon_badge.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/guardian_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../providers/guardian_provider.dart';

class GuardianDetailScreen extends ConsumerStatefulWidget {
  final Guardian guardian;

  const GuardianDetailScreen({super.key, required this.guardian});

  @override
  ConsumerState<GuardianDetailScreen> createState() =>
      _GuardianDetailScreenState();
}

class _GuardianDetailScreenState extends ConsumerState<GuardianDetailScreen> {
  late bool _gpsEnabled;
  late bool _micEnabled;
  late bool _videoEnabled;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _gpsEnabled = widget.guardian.permissions['gps'] ?? false;
    _micEnabled = widget.guardian.permissions['mic'] ?? false;
    _videoEnabled = widget.guardian.permissions['video'] ?? false;
    _loadPeerProfile();
  }

  String _getPeerUserId(String? currentUserId) {
    if (widget.guardian.guardianId.isNotEmpty &&
        widget.guardian.guardianId != currentUserId) {
      return widget.guardian.guardianId;
    }
    if (widget.guardian.ownerId.isNotEmpty &&
        widget.guardian.ownerId != currentUserId) {
      return widget.guardian.ownerId;
    }
    return widget.guardian.guardianId;
  }

  Future<void> _loadPeerProfile() async {
    try {
      final currentUserId = ref.read(authProvider).user?.id;
      final peerId = _getPeerUserId(currentUserId);
      if (peerId.isNotEmpty) {
        final profileRow = await ref
            .read(supabaseServiceProvider)
            .client
            .from('public_profiles')
            .select('avatar_url')
            .eq('id', peerId)
            .maybeSingle();
        if (profileRow != null && mounted) {
          setState(() {
            _avatarUrl = profileRow['avatar_url'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openChat() async {
    final currentUserId = ref.read(authProvider).user?.id;
    final peerId = _getPeerUserId(currentUserId);
    if (peerId.isEmpty) {
      MekaarSnackbar.error(context, 'Tidak dapat menemukan kontak obrolan.');
      return;
    }

    try {
      final roomId = await ref.read(chatRepositoryProvider).createRoom(
        peerId,
        'guardian',
      );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'chatId': roomId,
          'chatName': widget.guardian.name,
          'chatAvatar': widget.guardian.name.isNotEmpty
              ? widget.guardian.name[0]
              : 'U',
          'chatAvatarUrl': _avatarUrl,
          'isGuardian': true,
          'otherUserId': peerId,
        },
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal membuka obrolan: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _initiateCall() async {
    final currentUserId = ref.read(authProvider).user?.id;
    final peerId = _getPeerUserId(currentUserId);
    if (currentUserId == null || peerId.isEmpty) {
      MekaarSnackbar.error(context, 'Panggilan tidak tersedia.');
      return;
    }

    try {
      final roomId = await ref.read(chatRepositoryProvider).createRoom(
        peerId,
        'guardian',
      );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.call,
        arguments: {
          'roomId': roomId,
          'chatName': widget.guardian.name,
          'callerId': currentUserId,
          'receiverId': peerId,
          'isCaller': true,
          'callType': 'voice',
        },
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal memulai panggilan: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  void _trackGuardian() {
    Navigator.pushNamed(context, AppRoutes.guardianTracking);
  }

  Future<void> _togglePermission(String type, bool value) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final previousGps = _gpsEnabled;
    final previousMic = _micEnabled;
    final previousVideo = _videoEnabled;

    setState(() {
      if (type == 'gps') _gpsEnabled = value;
      if (type == 'mic') _micEnabled = value;
      if (type == 'video') _videoEnabled = value;
    });

    try {
      await ref.read(guardianProvider.notifier).updateGuardianPermissions(
        widget.guardian.id,
        {'gps': _gpsEnabled, 'mic': _micEnabled, 'video': _videoEnabled},
        'stream_only',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsEnabled = previousGps;
          _micEnabled = previousMic;
          _videoEnabled = previousVideo;
        });
        MekaarSnackbar.error(
          context,
          'Gagal memperbarui izin: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _initiateSwap() async {
    Navigator.pushNamed(
      context,
      '/guardian/swap',
      arguments: {'guardian': widget.guardian},
    );
  }

  Future<void> _removeGuardian() async {
    final confirmed = await MekaarDialog.showConfirmation<bool>(
      context: context,
      title: 'Hapus Guardian?',
      message:
          'Anda akan menghapus ${widget.guardian.name} dari daftar guardian. Semua izin akses akan dicabut.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Hapus',
            style: TextStyle(
              color: MekaarColors.sosRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    if (confirmed == true && mounted) {
      await ref
          .read(guardianProvider.notifier)
          .removeGuardian(widget.guardian.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _confirmBreakGuardian() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Putus Paksa Guardian?',
      message:
          'Hubungan dengan ${widget.guardian.name} akan diputus secara instan dan ia diblokir mengirim undangan selama 24 jam.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref
                  .read(guardianProvider.notifier)
                  .breakGuardian(widget.guardian.id);
              if (mounted) {
                MekaarSnackbar.success(
                  context,
                  'Hubungan dengan ${widget.guardian.name} diputus secara paksa.',
                );
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                MekaarSnackbar.error(
                  context,
                  'Gagal memutus hubungan: ${e.toString().replaceAll('Exception: ', '')}',
                );
              }
            }
          },
          child: const Text(
            'Putus Paksa',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmBlockGuardian() async {
    final confirmed = await MekaarDialog.showConfirmation<bool>(
      context: context,
      title: 'Blokir Guardian?',
      message:
          'Hubungan dengan ${widget.guardian.name} akan diputus, dihapus dari daftar Guardian, dan kontak ini akan diblokir total dari mengirim pesan maupun undangan.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Blokir Total',
            style: TextStyle(
              color: MekaarColors.sosRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    if (confirmed == true && mounted) {
      try {
        final currentUserId = ref.read(authProvider).user?.id;
        final guardianUserId = _getPeerUserId(currentUserId);
        // 1. Putus & Hapus Guardian
        await ref
            .read(guardianProvider.notifier)
            .removeGuardian(widget.guardian.id);
        // 2. Blokir Akun Pengguna
        if (guardianUserId.isNotEmpty) {
          await ref.read(blockProvider.notifier).blockUser(guardianUserId);
        }
        if (mounted) {
          MekaarSnackbar.success(
            context,
            '${widget.guardian.name} telah diputus dan diblokir total.',
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          MekaarSnackbar.error(
            context,
            'Gagal memblokir: ${e.toString().replaceAll('Exception: ', '')}',
          );
        }
      }
    }
  }

  Widget _buildActionHubItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
  }) {
    final isDark = MekaarColors.isDarkContext(context);
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.65);
    final glassBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.07),
      width: 1.0,
    );

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MekaarGlassBlurContainer(
            isFloating: true,
            height: 52,
            borderRadius: BorderRadius.circular(MekaarRadius.lg),
            padding: EdgeInsets.zero,
            border: glassBorder,
            customColor: isActive
                ? MekaarColors.guardianTeal.withValues(alpha: 0.20)
                : glassBg,
            child: InkWell(
              borderRadius: BorderRadius.circular(MekaarRadius.lg),
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                onTap();
              },
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor ??
                      (isActive
                          ? MekaarColors.guardianTeal
                          : MekaarColors.textPrimaryOf(context)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: MekaarTypography.labelSM.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? MekaarColors.guardianTeal
                  : MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.guardian.status == 'pending';
    final isExpired = widget.guardian.isExpired;

    return MekaarScaffold(
      flat: true,
      appBar: CustomAppBar(
        title: 'Detail Guardian',
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(SolarIconsOutline.menuDotsCircle),
            tooltip: 'Menu Opsi Guardian',
            onSelected: (value) {
              if (value == 'break') {
                _confirmBreakGuardian();
              } else if (value == 'remove') {
                _removeGuardian();
              } else if (value == 'block') {
                _confirmBlockGuardian();
              }
            },
            itemBuilder: (ctx) => [
              if (!isPending && !isExpired)
                const PopupMenuItem(
                  value: 'break',
                  child: Row(
                    children: [
                      Icon(
                        SolarIconsOutline.linkBroken,
                        size: 18,
                        color: MekaarColors.warnAmber,
                      ),
                      SizedBox(width: 10),
                      Text('Putus Paksa (Putuskan Izin)'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.trashBinMinimalistic,
                      size: 18,
                      color: MekaarColors.sosRed,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Hapus Guardian',
                      style: TextStyle(color: MekaarColors.sosRed),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.userBlock,
                      size: 18,
                      color: MekaarColors.sosRed,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Blokir Guardian',
                      style: TextStyle(color: MekaarColors.sosRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // ── 1. Header Profil (Avatar Besar di Tengah, Nama, Email, Badge) ──
            Center(
              child: Column(
                children: [
                  Avatar(
                    initial: widget.guardian.name.isNotEmpty
                        ? widget.guardian.name[0]
                        : 'U',
                    imageUrl: _avatarUrl,
                    size: 88,
                    isGuardian: widget.guardian.status == 'active',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.guardian.name,
                    style: MekaarTypography.headingMD.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.guardian.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.guardian.email,
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textMutedOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildStatusBadge(isPending, isExpired),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Quick Action Hub (4 Tombol Frosted Glass) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildActionHubItem(
                    icon: SolarIconsOutline.chatRoundDots,
                    label: 'Obrolan',
                    onTap: _openChat,
                  ),
                  const SizedBox(width: 12),
                  _buildActionHubItem(
                    icon: SolarIconsOutline.phone,
                    label: 'Panggilan',
                    onTap: _initiateCall,
                  ),
                  const SizedBox(width: 12),
                  _buildActionHubItem(
                    icon: SolarIconsOutline.mapPointWave,
                    label: 'Lacak GPS',
                    onTap: _trackGuardian,
                  ),
                  const SizedBox(width: 12),
                  _buildActionHubItem(
                    icon: SolarIconsOutline.refresh,
                    label: 'Tukar Posisi',
                    onTap: _initiateSwap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. Detail Konten Pengaturan ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Expiry Info Card ──
                  if (!isPending && !isExpired) ...[
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const MekaarIconBadge(
                            icon: SolarIconsOutline.stopwatch,
                            color: MekaarColors.success,
                            backgroundColor: MekaarColors.successLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Izin Berakhir',
                                  style: MekaarTypography.labelLG,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.guardian.daysRemaining} hari lagi — perlu diperbarui agar tetap aktif.',
                                  style: MekaarTypography.bodySM,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (isExpired) ...[
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const MekaarIconBadge(
                            icon: SolarIconsOutline.danger,
                            color: MekaarColors.sosRed,
                            backgroundColor: MekaarColors.sosLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Izin guardian ini sudah kadaluarsa. Simpan ulang untuk mengaktifkan kembali.',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.sosRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Izin Keamanan Section ──
                  Text(
                    'IZIN KEAMANAN (HANYA AKTIF SAAT SOS)',
                    style: MekaarTypography.overline,
                  ),
                  const SizedBox(height: 10),
                  CustomCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          activeTrackColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          secondary: MekaarIconBadge(
                            icon: SolarIconsOutline.mapPoint,
                            color: _gpsEnabled
                                ? MekaarColors.info
                                : MekaarColors.textMutedOf(context),
                            backgroundColor: _gpsEnabled
                                ? MekaarColors.infoLight
                                : MekaarColors.surface2Of(context),
                          ),
                          title: Text(
                            'Lacak Lokasi GPS',
                            style: MekaarTypography.labelLG,
                          ),
                          subtitle: Text(
                            'Koordinat real-time dikirim ke guardian saat SOS.',
                            style: MekaarTypography.bodySM,
                          ),
                          value: _gpsEnabled,
                          onChanged: (v) => _togglePermission('gps', v),
                        ),
                        const MekaarCardDivider(),
                        SwitchListTile(
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          activeTrackColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          secondary: MekaarIconBadge(
                            icon: SolarIconsOutline.microphone,
                            color: _micEnabled
                                ? MekaarColors.guardianTeal
                                : MekaarColors.textMutedOf(context),
                            backgroundColor: _micEnabled
                                ? MekaarColors.guardianLight
                                : MekaarColors.surface2Of(context),
                          ),
                          title: Text(
                            'Akses Mikrofon',
                            style: MekaarTypography.labelLG,
                          ),
                          subtitle: Text(
                            'Guardian mendengar audio sekitar perangkat saat SOS.',
                            style: MekaarTypography.bodySM,
                          ),
                          value: _micEnabled,
                          onChanged: (v) => _togglePermission('mic', v),
                        ),
                        const MekaarCardDivider(),
                        SwitchListTile(
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          activeTrackColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          secondary: MekaarIconBadge(
                            icon: SolarIconsOutline.videocamera,
                            color: _videoEnabled
                                ? MekaarColors.guardianTeal
                                : MekaarColors.textMutedOf(context),
                            backgroundColor: _videoEnabled
                                ? MekaarColors.guardianLight
                                : MekaarColors.surface2Of(context),
                          ),
                          title: Text(
                            'Akses Kamera (Video Darurat)',
                            style: MekaarTypography.labelLG,
                          ),
                          subtitle: Text(
                            'Anda dapat mengirim video darurat ke guardian saat SOS aktif.',
                            style: MekaarTypography.bodySM,
                          ),
                          value: _videoEnabled,
                          onChanged: (v) => _togglePermission('video', v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Informasi Transmisi & Privasi ──
                  Text(
                    'INFORMASI TRANSMISI & PRIVASI',
                    style: MekaarTypography.overline,
                  ),
                  const SizedBox(height: 10),
                  MekaarBanner(
                    color: MekaarColors.primaryOf(context),
                    icon: SolarIconsOutline.shieldCheck,
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Transmisi Langsung (Zero-Knowledge)',
                          style: MekaarTypography.labelLG.copyWith(
                            color: MekaarColors.textPrimaryOf(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Audio dan video SOS hanya disiarkan langsung ke Guardian saat darurat. Tidak ada rekaman yang disimpan di server atau cloud demi menjaga privasi penuh.',
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 4. Tindakan & Zona Bahaya (Grouped Destructive Card) ──
                  Text(
                    'TINDAKAN & ZONA BAHAYA',
                    style: MekaarTypography.overline.copyWith(
                      color: MekaarColors.sosRed,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        if (!isPending && !isExpired) ...[
                          ListTile(
                            leading: const MekaarIconBadge(
                              icon: SolarIconsOutline.linkBroken,
                              color: MekaarColors.warning,
                              backgroundColor: MekaarColors.warningLight,
                            ),
                            title: Text(
                              'Putus Paksa',
                              style: MekaarTypography.labelLG.copyWith(
                                color: MekaarColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Putus hubungan instan dan blokir undangan selama 24 jam.',
                              style: MekaarTypography.bodySM,
                            ),
                            onTap: _confirmBreakGuardian,
                          ),
                          const MekaarCardDivider(),
                        ],
                        ListTile(
                          leading: const MekaarIconBadge(
                            icon: SolarIconsOutline.trashBinMinimalistic,
                            color: MekaarColors.sosRed,
                            backgroundColor: MekaarColors.sosLight,
                          ),
                          title: Text(
                            'Hapus Guardian',
                            style: MekaarTypography.labelLG.copyWith(
                              color: MekaarColors.sosRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Cabut semua izin dan hapus dari daftar guardian.',
                            style: MekaarTypography.bodySM,
                          ),
                          onTap: _removeGuardian,
                        ),
                        const MekaarCardDivider(),
                        ListTile(
                          leading: const MekaarIconBadge(
                            icon: SolarIconsOutline.userBlock,
                            color: MekaarColors.sosRed,
                            backgroundColor: MekaarColors.sosLight,
                          ),
                          title: Text(
                            'Blokir Guardian',
                            style: MekaarTypography.labelLG.copyWith(
                              color: MekaarColors.sosRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Putus hubungan, hapus dari daftar, dan blokir total kontak.',
                            style: MekaarTypography.bodySM,
                          ),
                          onTap: _confirmBlockGuardian,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPending, bool isExpired) {
    if (isPending) {
      return const MekaarBadge(
        label: 'Menunggu Persetujuan',
        color: MekaarColors.warning,
      );
    } else if (isExpired) {
      return const MekaarBadge(
        label: 'Kadaluarsa',
        color: MekaarColors.sosRed,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MekaarColors.guardianTeal.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MekaarColors.safeTextOf(context),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Guardian Aktif',
            style: TextStyle(
              color: MekaarColors.safeTextOf(context),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
