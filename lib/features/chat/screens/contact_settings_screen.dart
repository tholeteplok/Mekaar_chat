import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/private_vault_provider.dart';
import '../../chat/widgets/private_vault_dialogs.dart';
import '../../chat/widgets/chat_room_privacy_sheet.dart';
import '../../settings/providers/block_provider.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/repositories/report_repository.dart';

class ContactSettingsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String chatName;
  final String chatAvatar;
  final String otherUserId;
  final bool isGuardian;

  const ContactSettingsScreen({
    super.key,
    required this.roomId,
    required this.chatName,
    required this.chatAvatar,
    required this.otherUserId,
    this.isGuardian = false,
  });

  @override
  ConsumerState<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends ConsumerState<ContactSettingsScreen> {
  bool _isMuted = false;
  bool _isLoading = true;
  bool _isBlocked = false;
  String _e2eeFingerprint = '';
  bool _showE2eeFingerprint = false;
  String? _avatarUrl;
  String? _username;
  String? _bio;
  DateTime? _lastSeenAt;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final repo = ref.read(chatRepositoryProvider);
    final prefs = await repo.getRoomPreferences(widget.roomId);
    final blocked = await ref.read(blockRepositoryProvider).isBlocked(widget.otherUserId);
    final peerPub = await E2eeService.instance.getPeerPublicKey(widget.otherUserId);
    final fingerprint = peerPub != null ? E2eeService.getPublicKeyFingerprint(peerPub) : '';
    final lastSeen = await repo.getLastSeen(widget.otherUserId);

    String? peerAvatarUrl;
    String? peerUsername;
    String? peerBio;
    try {
      final profileRow = await ref.read(supabaseServiceProvider).client
          .from('public_profiles')
          .select('avatar_url, username, bio')
          .eq('id', widget.otherUserId)
          .maybeSingle();
      peerAvatarUrl = profileRow?['avatar_url'] as String?;
      peerUsername = profileRow?['username'] as String?;
      peerBio = profileRow?['bio'] as String?;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isMuted = prefs?.isMuted ?? false;
      _isBlocked = blocked;
      _e2eeFingerprint = fingerprint;
      _avatarUrl = peerAvatarUrl;
      _username = peerUsername;
      _bio = peerBio;
      _lastSeenAt = lastSeen;
      _isLoading = false;
    });
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null) {
      MekaarSnackbar.error(context, 'Panggilan tidak tersedia untuk obrolan ini.');
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.call,
      arguments: {
        'roomId': widget.roomId,
        'chatName': widget.chatName,
        'callerId': currentUserId,
        'receiverId': widget.otherUserId,
        'isCaller': true,
        'callType': callType,
      },
    );
  }

  String _formatPresenceSubtitle(DateTime? otherLastSeen) {
    if (otherLastSeen == null) return 'Terakhir dilihat baru-baru ini';

    final now = DateTime.now();
    final lastSeen = otherLastSeen.toLocal();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 2) {
      return 'Online';
    }

    final isSameDay = now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == lastSeen.year &&
        yesterday.month == lastSeen.month &&
        yesterday.day == lastSeen.day;

    final hourStr = lastSeen.hour.toString().padLeft(2, '0');
    final minuteStr = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (isSameDay) {
      return 'Terakhir dilihat hari ini pukul $timeStr';
    } else if (isYesterday) {
      return 'Terakhir dilihat kemarin pukul $timeStr';
    } else if (now.year == lastSeen.year) {
      const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return 'Terakhir dilihat ${lastSeen.day} ${monthNames[lastSeen.month - 1]} pukul $timeStr';
    } else {
      return 'Terakhir dilihat ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }

  bool _isCurrentlyOnline(DateTime? otherLastSeen) {
    if (otherLastSeen == null) return false;
    final diff = DateTime.now().difference(otherLastSeen.toLocal());
    return diff.inMinutes < 2;
  }

  Future<void> _toggleMute(bool muted) async {
    final previous = _isMuted;
    setState(() => _isMuted = muted);
    try {
      await ref.read(chatRepositoryProvider).updateRoomMute(widget.roomId, muted);
    } catch (e) {
      if (mounted) {
        setState(() => _isMuted = previous);
        MekaarSnackbar.error(
          context,
          'Gagal menyimpan pengaturan mute: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  Future<void> _toggleBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        title: _isBlocked ? 'Buka Blokir?' : 'Blokir ${widget.chatName}?',
        message: _isBlocked
            ? 'Anda akan menerima pesan dari ${widget.chatName} lagi.'
            : 'Blokir ${widget.chatName}? Anda tidak akan menerima pesan dari kontak ini.',
        isDestructive: !_isBlocked,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: MekaarColors.textMutedOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBlocked
                  ? MekaarColors.guardianTeal
                  : MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: Text(_isBlocked ? 'Buka Blokir' : 'Blokir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_isBlocked) {
        await ref.read(blockProvider.notifier).unblockUser(widget.otherUserId);
      } else {
        await ref.read(blockProvider.notifier).blockUser(widget.otherUserId);
      }
      if (mounted) setState(() => _isBlocked = !_isBlocked);
    }
  }

  Widget _buildActionHubItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            borderRadius: BorderRadius.circular(16),
            padding: EdgeInsets.zero,
            border: glassBorder,
            customColor: isActive
                ? MekaarColors.guardianTeal.withValues(alpha: 0.20)
                : glassBg,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? (isActive ? MekaarColors.guardianTeal : MekaarColors.textPrimaryOf(context)),
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
              color: isActive ? MekaarColors.guardianTeal : MekaarColors.textSecondaryOf(context),
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
    final isOnline = _isCurrentlyOnline(_lastSeenAt);

    return MekaarScaffold(
      flat: true,
      appBar: const CustomAppBar(
        title: 'Info Kontak',
      ),
      body: _isLoading
          ? const MekaarStateView(
              pose: MikaPose.ask,
              title: 'Memuat Info Kontak',
              message: 'Mengambil detail profil kontak Anda…',
              semanticLabel: 'Memuat info kontak',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── 1. Header Profil (Avatar, Nama, Username, Status Online) ──
                Center(
                  child: Column(
                    children: [
                      Avatar(
                        initial: widget.chatAvatar.isNotEmpty ? widget.chatAvatar : widget.chatName[0],
                        imageUrl: _avatarUrl,
                        size: 88,
                        isGuardian: widget.isGuardian,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.chatName,
                        style: MekaarTypography.headingMD.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_username != null && _username!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$_username',
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textMutedOf(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Status Presensi (Patuh Privasi Global)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? MekaarColors.success
                                  : MekaarColors.textMutedOf(context),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatPresenceSubtitle(_lastSeenAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isOnline
                                  ? MekaarColors.success
                                  : MekaarColors.textMutedOf(context),
                            ),
                          ),
                        ],
                      ),
                      if (widget.isGuardian) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MekaarColors.guardianTeal.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(SolarIconsOutline.shieldUser, size: 13, color: MekaarColors.guardianTeal),
                              SizedBox(width: 4),
                              Text('Guardian', style: TextStyle(color: MekaarColors.guardianTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 2. Quick Action Hub (4 Tombol Frosted Glass) ──
                Consumer(
                  builder: (context, ref, _) {
                    final hiddenRooms = ref.watch(hiddenRoomIdsProvider);
                    final isHidden = hiddenRooms.contains(widget.roomId);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildActionHubItem(
                            icon: SolarIconsOutline.chatRoundDots,
                            label: 'Obrolan',
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          _buildActionHubItem(
                            icon: SolarIconsOutline.phone,
                            label: 'Panggilan',
                            onTap: () => _initiateCall('voice'),
                          ),
                          const SizedBox(width: 12),
                          _buildActionHubItem(
                            icon: SolarIconsOutline.videocamera,
                            label: 'Video',
                            onTap: () => _initiateCall('video'),
                          ),
                          const SizedBox(width: 12),
                          _buildActionHubItem(
                            icon: isHidden ? SolarIconsOutline.eye : SolarIconsOutline.eyeClosed,
                            label: isHidden ? 'Tampilkan' : 'Sembunyikan',
                            isActive: isHidden,
                            onTap: () => PrivateVaultDialogs.toggleRoomHiddenWithAuth(
                              context,
                              ref,
                              roomId: widget.roomId,
                              chatName: widget.chatName,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── 3. Card Bio / Catatan Kontak ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CustomCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'BIO / TENTANG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            const Spacer(),
                            if (_bio != null && _bio!.trim().isNotEmpty)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _bio!));
                                  HapticService.trigger(MekaarHapticIntent.selection);
                                  MekaarSnackbar.success(context, 'Bio berhasil disalin.');
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      SolarIconsOutline.copy,
                                      size: 13,
                                      color: MekaarColors.accentOf(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Salin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: MekaarColors.accentOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          (_bio != null && _bio!.trim().isNotEmpty)
                              ? _bio!
                              : 'Belum ada bio atau catatan keamanan.',
                          style: MekaarTypography.bodyMD.copyWith(
                            color: (_bio != null && _bio!.trim().isNotEmpty)
                                ? MekaarColors.textPrimaryOf(context)
                                : MekaarColors.textMutedOf(context),
                            fontStyle: (_bio != null && _bio!.trim().isNotEmpty)
                                ? FontStyle.normal
                                : FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── 4. Card Pengaturan Obrolan ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pengaturan Obrolan',
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
                  child: CustomCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Pengaturan Privasi Obrolan Terpusat
                        ListTile(
                          leading: const Icon(
                            SolarIconsOutline.shieldKeyhole,
                            color: AppColors.blue,
                          ),
                          title: const Text(
                            'Pengaturan Privasi Obrolan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Proteksi layar, anti-forward, pesan menghilang, & self-destruct',
                            style: TextStyle(
                              fontSize: 12,
                              color: MekaarColors.textMutedOf(context),
                            ),
                          ),
                          trailing: Icon(
                            SolarIconsOutline.altArrowRight,
                            size: 16,
                            color: MekaarColors.textMutedOf(context),
                          ),
                          onTap: () {
                            ChatRoomPrivacySheet.show(
                              context,
                              roomId: widget.roomId,
                              onSettingsChanged: () {
                                _loadPreferences();
                              },
                            );
                          },
                        ),
                        const MekaarCardDivider(),

                        // Mute Switch
                        SwitchListTile(
                          secondary: const Icon(SolarIconsOutline.bellOff, color: MekaarColors.warnAmber),
                          title: Text('Bisukan Notifikasi', style: MekaarTypography.labelLG),
                          subtitle: Text('Nonaktifkan suara notifikasi dari chat ini', style: MekaarTypography.bodySM),
                          value: _isMuted,
                          activeTrackColor: MekaarColors.guardianTeal,
                          onChanged: _toggleMute,
                        ),
                        const MekaarCardDivider(),

                        // E2EE Safety Number Fingerprint
                        ListTile(
                          leading: const Icon(SolarIconsOutline.shieldCheck, color: MekaarColors.guardianTeal),
                          title: const Text('Sidik Jari Keamanan E2EE'),
                          subtitle: _e2eeFingerprint.isEmpty
                              ? Text('Belum mengaktifkan E2EE', style: MekaarTypography.bodySM)
                              : _showE2eeFingerprint
                                  ? Text(
                                      _e2eeFingerprint,
                                      style: MekaarTypography.bodySM.copyWith(
                                        fontFamily: 'monospace',
                                        letterSpacing: 1.0,
                                      ),
                                    )
                                  : Text(
                                      'Ketuk ikon mata untuk melihat',
                                      style: MekaarTypography.bodySM,
                                    ),
                          trailing: _e2eeFingerprint.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    _showE2eeFingerprint ? SolarIconsOutline.eyeClosed : SolarIconsOutline.eye,
                                    color: MekaarColors.textSecondaryOf(context),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showE2eeFingerprint = !_showE2eeFingerprint;
                                    });
                                  },
                                )
                              : null,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(
                                      SolarIconsBold.shieldCheck,
                                      color: MekaarColors.guardianTeal,
                                      size: 26,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Mekaar Aegis Shield (E2EE)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pesan dan panggilan dalam obrolan ini dilindungi oleh enkripsi ujung-ke-ujung (E2EE) protokol Aegis menggunakan pasangan kunci asimetris X25519 & ChaCha20-Poly1305.',
                                      style: TextStyle(
                                        color: MekaarColors.textPrimaryOf(context),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (_e2eeFingerprint.isNotEmpty) ...[
                                      Text(
                                        'Sidik Jari Kunci Keamanan:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: MekaarColors.textPrimaryOf(context),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: MekaarColors.surface2Of(context),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: SelectableText(
                                          _e2eeFingerprint,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            color: MekaarColors.textPrimaryOf(context),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    const Text(
                                      '🔒 Komitmen Privasi Mutlak:',
                                      style: TextStyle(
                                        color: MekaarColors.guardianTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hanya Anda dan lawan bicara yang memegang kunci untuk membaca pesan ini. Server MEKAAR tidak memiliki akses ke konten percakapan Anda.',
                                      style: TextStyle(
                                        color: MekaarColors.textMutedOf(context),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text(
                                      'Tutup',
                                      style: TextStyle(
                                        color: MekaarColors.guardianTeal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 5. Card Tindakan (Danger Zone) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tindakan',
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
                  child: CustomCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Hapus Chat
                        ListTile(
                          leading: const Icon(SolarIconsOutline.trashBinTrash, color: MekaarColors.sosRed),
                          title: const Text('Hapus Chat'),
                          titleTextStyle: const TextStyle(color: MekaarColors.sosRed),
                          onTap: () {
                            MekaarDialog.showConfirmation<void>(
                              context: context,
                              title: 'Hapus Chat?',
                              message: 'Obrolan akan hilang dari daftar chat Anda.',
                              isDestructive: true,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MekaarColors.sosRed,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await ref.read(chatActionsProvider).deleteChat(widget.roomId);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Hapus'),
                                ),
                              ],
                            );
                          },
                        ),
                        const MekaarCardDivider(),

                        // Blokir
                        ListTile(
                          leading: Icon(
                            SolarIconsOutline.dangerTriangle,
                            color: _isBlocked ? MekaarColors.guardianTeal : MekaarColors.sosCoral,
                          ),
                          title: Text(_isBlocked ? 'Buka Blokir Kontak' : 'Blokir Kontak'),
                          onTap: _toggleBlock,
                        ),
                        const MekaarCardDivider(),

                        // Laporkan Pengguna
                        ListTile(
                          leading: const Icon(SolarIconsOutline.flag, color: MekaarColors.warnAmber),
                          title: const Text('Laporkan Pengguna'),
                          onTap: _showReportDialog,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => _ReportUserDialog(
        otherUserId: widget.otherUserId,
        roomId: widget.roomId,
      ),
    );
  }
}

class _ReportUserDialog extends ConsumerStatefulWidget {
  final String otherUserId;
  final String roomId;

  const _ReportUserDialog({
    required this.otherUserId,
    required this.roomId,
  });

  @override
  ConsumerState<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends ConsumerState<_ReportUserDialog> {
  String _selectedCategory = 'spam';
  late final TextEditingController _reasonController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      MekaarSnackbar.error(context, 'Mohon isi alasan laporan.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(reportRepositoryProvider).submitReport(
        reportedUserId: widget.otherUserId,
        roomId: widget.roomId,
        category: _selectedCategory,
        reason: reason,
      );
      if (mounted) {
        Navigator.pop(context);
        MekaarSnackbar.success(context, 'Laporan Anda telah dikirim dan akan ditinjau tim moderasi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        MekaarSnackbar.error(context, 'Gagal mengirim laporan: ${ErrorResolver.resolve(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Laporkan Pengguna'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih kategori pelanggaran:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'spam', child: Text('Spam / Iklan')),
                DropdownMenuItem(value: 'harassment', child: Text('Pelecehan / Ancaman')),
                DropdownMenuItem(value: 'inappropriate', child: Text('Konten Tidak Pantas')),
                DropdownMenuItem(value: 'fraud', child: Text('Penipuan / Fraud')),
                DropdownMenuItem(value: 'other', child: Text('Lainnya')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Jelaskan alasan laporan secara rinci:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Tuliskan konteks pelanggaran...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.warnAmber,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kirim Laporan'),
        ),
      ],
    );
  }
}
