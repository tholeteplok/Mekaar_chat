import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/guest_session_guard.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mekaar_badge.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_section_header.dart';
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
  late DateTime? _expiresAt;
  late String _status;
  bool _isUpdatingDuration = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _gpsEnabled = widget.guardian.permissions['gps'] ?? false;
    _micEnabled = widget.guardian.permissions['mic'] ?? false;
    _videoEnabled = widget.guardian.permissions['video'] ?? false;
    _expiresAt = widget.guardian.expiresAt;
    _status = widget.guardian.status;
    _loadPeerProfile();
  }

  bool get _isPending => _status == 'pending';
  bool get _isPermanent => _expiresAt == null;

  bool get _isExpired {
    if (_status == 'expired') return true;
    final exp = _expiresAt;
    if (exp == null) return false;
    return exp.toUtc().isBefore(DateTime.now().toUtc());
  }

  int get _remainingDays {
    final exp = _expiresAt;
    if (exp == null) return 0;
    final diff = exp.toUtc().difference(DateTime.now().toUtc());
    if (diff.isNegative) return 0;
    return diff.inDays;
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(local);
    } catch (_) {
      return '${local.day}/${local.month}/${local.year}';
    }
  }

  String _formatExpiryLabel() {
    if (_isExpired) {
      return 'Masa aktif telah berakhir (ketuk untuk perpanjang)';
    }
    if (_isPermanent) {
      return 'Permanen (Berlaku tanpa batas waktu)';
    }
    final remaining = _remainingDays;
    final remainingPart =
        remaining == 0 ? '< 1 hari lagi' : 'Sisa $remaining hari';
    return '$remainingPart • Berakhir ${_formatDate(_expiresAt!)}';
  }

  Future<void> _applyGuardianDuration(
    DateTime? newExpiresAt, {
    required String successLabel,
  }) async {
    final prevExpiresAt = _expiresAt;
    final prevStatus = _status;
    final wasExpired = _isExpired;

    setState(() {
      _isUpdatingDuration = true;
      _expiresAt = newExpiresAt;
      if (wasExpired) {
        _status = 'active';
      }
    });

    if (GuestSessionGuard.isRestrictedSession(ref)) {
      if (mounted) {
        setState(() => _isUpdatingDuration = false);
        MekaarSnackbar.success(context, successLabel);
      }
      return;
    }

    try {
      await ref.read(guardianProvider.notifier).updateGuardianDuration(
            widget.guardian.id,
            expiresAt: newExpiresAt,
            reactivateIfExpired: wasExpired,
          );
      if (mounted) {
        MekaarSnackbar.success(context, successLabel);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _expiresAt = prevExpiresAt;
          _status = prevStatus;
        });
        MekaarSnackbar.error(
          context,
          'Gagal memperbarui masa aktif: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDuration = false);
      }
    }
  }

  Future<void> _confirmPermanentDuration() async {
    final confirmed = await MekaarDialog.showConfirmation<bool>(
      context: context,
      title: 'Jadikan Guardian Permanen?',
      message:
          'Akses darurat untuk ${widget.guardian.name} tidak akan memiliki tanggal kedaluwarsa otomatis dan tetap aktif sampai Anda mencabut, memutus, atau menghapus hubungan ini secara manual.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.warnAmber,
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tetap Jadikan Permanen'),
        ),
      ],
    );

    if (confirmed == true && mounted) {
      await _applyGuardianDuration(
        null,
        successLabel: 'Masa aktif Guardian diatur menjadi Permanen.',
      );
    }
  }

  Future<void> _pickCustomExpiryDate() async {
    final nowLocal = DateTime.now();
    final firstDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day)
        .add(const Duration(days: 1));
    final lastDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day)
        .add(const Duration(days: 365));
    final currentLocal = _expiresAt?.toLocal();
    final initialDate = (currentLocal != null &&
            !currentLocal.isBefore(firstDate) &&
            !currentLocal.isAfter(lastDate))
        ? DateTime(currentLocal.year, currentLocal.month, currentLocal.day)
        : firstDate.add(const Duration(days: 6));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Pilih Tanggal Berakhir Guardian',
      cancelText: 'Batal',
      confirmText: 'Simpan',
    );
    if (picked == null || !mounted) return;

    final endOfDayUtc =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59).toUtc();
    await _applyGuardianDuration(
      endOfDayUtc,
      successLabel: 'Masa aktif berakhir pada ${_formatDate(endOfDayUtc)}.',
    );
  }

  void _showDurationPickerSheet() {
    HapticService.trigger(MekaarHapticIntent.selection);
    MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      title: 'Masa Aktif Guardian',
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                SolarIconsOutline.clockCircle,
                color: MekaarColors.primaryOf(context),
              ),
              title: const Text('7 Hari dari Sekarang'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyGuardianDuration(
                  DateTime.now().toUtc().add(const Duration(days: 7)),
                  successLabel: 'Masa aktif Guardian diatur menjadi 7 hari.',
                );
              },
            ),
            ListTile(
              leading: Icon(
                SolarIconsOutline.calendar,
                color: MekaarColors.primaryOf(context),
              ),
              title: const Text('30 Hari dari Sekarang'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyGuardianDuration(
                  DateTime.now().toUtc().add(const Duration(days: 30)),
                  successLabel: 'Masa aktif Guardian diatur menjadi 30 hari.',
                );
              },
            ),
            ListTile(
              leading: Icon(
                SolarIconsOutline.calendarMark,
                color: MekaarColors.primaryOf(context),
              ),
              title: const Text('90 Hari (3 Bulan)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyGuardianDuration(
                  DateTime.now().toUtc().add(const Duration(days: 90)),
                  successLabel: 'Masa aktif Guardian diatur menjadi 90 hari.',
                );
              },
            ),
            ListTile(
              leading: const Icon(
                SolarIconsOutline.infinity,
                color: MekaarColors.warnAmber,
              ),
              title: const Text('Permanen (Tanpa Batas)'),
              subtitle: const Text(
                'Tetap aktif sampai dicabut atau dihapus secara manual',
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmPermanentDuration();
              },
            ),
            const MekaarCardDivider(),
            ListTile(
              leading: Icon(
                SolarIconsOutline.calendarAdd,
                color: MekaarColors.textSecondaryOf(context),
              ),
              title: const Text('Pilih Tanggal Berakhir...'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickCustomExpiryDate();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

    // Lapis 1 (Ephemeral RAM-Only): Mode Tamu/Duress hanya mengubah tampilan lokal sesi.
    if (GuestSessionGuard.isRestrictedSession(ref)) {
      return;
    }

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
    if (GuestSessionGuard.isRestrictedSession(ref)) {
      await GuestSessionGuard.triggerSafeSilentClose(ref);
      return;
    }
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
      if (GuestSessionGuard.isRestrictedSession(ref)) {
        await GuestSessionGuard.triggerSafeSilentClose(ref);
        return;
      }
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
            if (GuestSessionGuard.isRestrictedSession(ref)) {
              await GuestSessionGuard.triggerSafeSilentClose(ref);
              return;
            }
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
      if (GuestSessionGuard.isRestrictedSession(ref)) {
        await GuestSessionGuard.triggerSafeSilentClose(ref);
        return;
      }
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
    final isPending = _isPending;
    final isExpired = _isExpired;

    return MekaarScaffold(
      flat: true,
      appBar: MekaarTopBar(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──── 1. Header Profil (Avatar Besar di Tengah, Nama, Email, Badge) ────
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

            // ──── 2. Quick Action Hub (4 Tombol Frosted Glass) ────
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

            const SizedBox(height: 16),

            // ──── 2b. Manajemen Masa Aktif Guardian ────
            if (!isPending) ...[
              const MekaarSectionHeader(
                title: 'Masa Aktif Hubungan',
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const ValueKey('guardian_duration_tile'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  _isPermanent
                      ? SolarIconsOutline.infinity
                      : SolarIconsOutline.clockCircle,
                  color: _isExpired
                      ? MekaarColors.sosRed
                      : (_isPermanent
                            ? MekaarColors.warnAmber
                            : MekaarColors.primaryOf(context)),
                ),
                title: const Text(
                  'Masa Aktif Guardian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _formatExpiryLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isExpired
                        ? MekaarColors.sosRed
                        : MekaarColors.textMutedOf(context),
                  ),
                ),
                trailing: _isUpdatingDuration
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        SolarIconsOutline.altArrowRight,
                        size: 16,
                        color: MekaarColors.textMutedOf(context),
                      ),
                onTap: _isUpdatingDuration ? null : _showDurationPickerSheet,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: MekaarCardDivider(),
              ),
              const SizedBox(height: 16),
            ],

            // ──── 3. Izin Keamanan ────
            const MekaarSectionHeader(
              title: 'Izin Keamanan (Hanya Aktif Saat SOS)',
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              activeThumbColor: MekaarColors.primaryOf(context),
              activeTrackColor:
                  MekaarColors.primaryOf(context).withValues(alpha: 0.35),
              secondary: Icon(
                SolarIconsOutline.mapPoint,
                color: _gpsEnabled
                    ? MekaarColors.primaryOf(context)
                    : MekaarColors.textSecondaryOf(context),
              ),
              title: const Text(
                'Lacak Lokasi GPS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Koordinat real-time dikirim ke guardian saat SOS.',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
              value: _gpsEnabled,
              onChanged: (v) => _togglePermission('gps', v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: MekaarCardDivider(),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              activeThumbColor: MekaarColors.primaryOf(context),
              activeTrackColor:
                  MekaarColors.primaryOf(context).withValues(alpha: 0.35),
              secondary: Icon(
                SolarIconsOutline.microphone,
                color: _micEnabled
                    ? MekaarColors.primaryOf(context)
                    : MekaarColors.textSecondaryOf(context),
              ),
              title: const Text(
                'Akses Mikrofon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Guardian mendengar audio sekitar perangkat saat SOS.',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
              value: _micEnabled,
              onChanged: (v) => _togglePermission('mic', v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: MekaarCardDivider(),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              activeThumbColor: MekaarColors.primaryOf(context),
              activeTrackColor:
                  MekaarColors.primaryOf(context).withValues(alpha: 0.35),
              secondary: Icon(
                SolarIconsOutline.videocamera,
                color: _videoEnabled
                    ? MekaarColors.primaryOf(context)
                    : MekaarColors.textSecondaryOf(context),
              ),
              title: const Text(
                'Akses Kamera (Video Darurat)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Anda dapat mengirim video darurat ke guardian saat SOS aktif.',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
              value: _videoEnabled,
              onChanged: (v) => _togglePermission('video', v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: MekaarCardDivider(),
            ),

            if (isExpired) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MekaarBanner(
                  color: MekaarColors.sosRed,
                  icon: SolarIconsOutline.danger,
                  content: const Text(
                    'Izin guardian ini sudah kadaluarsa. Simpan ulang untuk mengaktifkan kembali.',
                    style: TextStyle(color: MekaarColors.sosRed),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ──── 4. Informasi Transmisi & Privasi ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Informasi Transmisi & Privasi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: MekaarColors.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MekaarBanner(
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
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ──── 5. Tindakan (Sesuai Info Kontak) ────
            const MekaarSectionHeader(
              title: 'Tindakan',
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            const SizedBox(height: 8),
            if (!isPending && !isExpired) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(
                  SolarIconsOutline.linkBroken,
                  color: MekaarColors.warnAmber,
                ),
                title: const Text('Putus Hubungan Guardian'),
                subtitle: const Text(
                  'Putus hubungan instan dan blokir undangan selama 24 jam',
                ),
                titleTextStyle: const TextStyle(
                  color: MekaarColors.warnAmber,
                  fontWeight: FontWeight.w600,
                ),
                subtitleTextStyle: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textSecondaryOf(context),
                ),
                onTap: _confirmBreakGuardian,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: MekaarCardDivider(),
              ),
            ],
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(
                SolarIconsOutline.trashBinMinimalistic,
                color: MekaarColors.sosRed,
              ),
              title: const Text('Hapus Guardian'),
              subtitle: const Text(
                'Cabut semua izin dan hapus dari daftar guardian',
              ),
              titleTextStyle: const TextStyle(
                color: MekaarColors.sosRed,
                fontWeight: FontWeight.w600,
              ),
              subtitleTextStyle: TextStyle(
                fontSize: 12,
                color: MekaarColors.textSecondaryOf(context),
              ),
              onTap: _removeGuardian,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: MekaarCardDivider(),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(
                SolarIconsOutline.userBlock,
                color: MekaarColors.sosRed,
              ),
              title: const Text('Blokir Kontak Guardian'),
              subtitle: const Text(
                'Putus hubungan, hapus dari daftar, dan blokir total kontak',
              ),
              titleTextStyle: const TextStyle(
                color: MekaarColors.sosRed,
                fontWeight: FontWeight.w600,
              ),
              subtitleTextStyle: TextStyle(
                fontSize: 12,
                color: MekaarColors.textSecondaryOf(context),
              ),
              onTap: _confirmBlockGuardian,
            ),
            const SizedBox(height: 32),
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
    final String remainingText;
    if (_isPermanent) {
      remainingText = ' • Permanen';
    } else if (_remainingDays > 0) {
      remainingText = ' • Sisa $_remainingDays hari';
    } else {
      remainingText = ' • < 1 hari';
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
            'Guardian Aktif$remainingText',
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
