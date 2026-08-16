import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/private_vault_provider.dart';
import '../../chat/widgets/private_vault_dialogs.dart';
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
  int? _disappearingOverrideHours;
  bool _isLoading = true;
  bool _isBlocked = false;
  String _e2eeFingerprint = '';
  bool _showE2eeFingerprint = false;
  String? _avatarUrl;

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
    // Tidak ada lagi fallback ke "pengaturan global" -- NULL/belum diatur
    // diperlakukan sama seperti 0 (Mati), murni per-room.
    
    String? peerAvatarUrl;
    try {
      final profileRow = await ref.read(supabaseServiceProvider).client
          .from('public_profiles')
          .select('avatar_url')
          .eq('id', widget.otherUserId)
          .maybeSingle();
      peerAvatarUrl = profileRow?['avatar_url'] as String?;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isMuted = prefs?.isMuted ?? false;
      _disappearingOverrideHours = prefs?.disappearingOverrideHours;
      _isBlocked = blocked;
      _e2eeFingerprint = fingerprint;
      _avatarUrl = peerAvatarUrl;
      _isLoading = false;
    });
  }

  Future<void> _toggleMute(bool muted) async {
    final previous = _isMuted;
    setState(() => _isMuted = muted);
    try {
      await ref.read(chatRepositoryProvider).updateRoomMute(widget.roomId, muted);
    } catch (e) {
      if (mounted) {
        setState(() => _isMuted = previous);
        MekaarSnackbar.error(context, 'Gagal menyimpan pengaturan mute: $e');
      }
    }
  }

  Future<void> _setDisappearing(int? hours) async {
    final previous = _disappearingOverrideHours;
    setState(() => _disappearingOverrideHours = hours);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateRoomDisappearingOverride(widget.roomId, hours);
    } catch (e) {
      if (mounted) {
        // Rollback tampilan optimis -- jangan sampai layar ini menunjukkan
        // pilihan baru seolah tersimpan padahal RPC gagal (lihat
        // migrations/40_fix_room_participant_rpcs_search_path.sql untuk
        // akar masalah yang sebelumnya membuat ini gagal 100% diam-diam).
        setState(() => _disappearingOverrideHours = previous);
        MekaarSnackbar.error(
          context,
          'Gagal menyimpan pengaturan pesan menghilang: $e',
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

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Avatar & Nama
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
                        style: MekaarTypography.headingMD.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.isGuardian) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(SolarIconsOutline.shieldUser, size: 14, color: MekaarColors.guardianTeal),
                            const SizedBox(width: 4),
                            const Text('Guardian', style: TextStyle(color: MekaarColors.guardianTeal, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Pengaturan Privasi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pengaturan Privasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Mute
                _buildSwitchTile(
                  icon: SolarIconsOutline.bellOff,
                  title: 'Bisukan Notifikasi',
                  subtitle: 'Nonaktifkan suara notifikasi dari chat ini',
                  value: _isMuted,
                  onChanged: _toggleMute,
                ),

                // Disappearing messages
                _buildDisappearingTile(),

                // E2EE Safety Number Fingerprint
                ListTile(
                  leading: const Icon(SolarIconsOutline.shieldKeyhole, color: MekaarColors.guardianTeal),
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
                  onTap: _e2eeFingerprint.isNotEmpty
                      ? () {
                          showDialog(
                            context: context,
                            builder: (ctx) => MekaarDialog(
                              icon: const Icon(
                                SolarIconsBold.shieldCheck,
                                color: MekaarColors.guardianTeal,
                                size: 28,
                              ),
                              title: 'Sidik Jari Keamanan',
                              message:
                                  'Untuk memverifikasi bahwa chat ini aman dan dienkripsi ujung-ke-ujung (E2EE) secara sah, cocokkan nomor berikut dengan perangkat milik kontak Anda:\n\n$_e2eeFingerprint',
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
                        }
                      : null,
                ),

                // Sembunyikan Kontak (Private Vault)
                Consumer(
                  builder: (context, ref, _) {
                    final hiddenRooms = ref.watch(hiddenRoomIdsProvider);
                    final isHidden = hiddenRooms.contains(widget.roomId);

                    return ListTile(
                      leading: Icon(
                        isHidden ? SolarIconsBold.shieldKeyhole : SolarIconsOutline.shieldKeyhole,
                        color: isHidden ? MekaarColors.guardianTeal : MekaarColors.textSecondaryOf(context),
                      ),
                      title: const Text('Sembunyikan Obrolan (Private Vault)'),
                      subtitle: Text(
                        isHidden
                            ? 'Obrolan disembunyikan. Masukkan kode rahasia di search bar untuk membuka.'
                            : 'Sembunyikan obrolan ini dari daftar utama.',
                        style: MekaarTypography.bodySM,
                      ),
                      trailing: Switch.adaptive(
                        value: isHidden,
                        activeTrackColor: MekaarColors.guardianTeal,
                        onChanged: (_) => PrivateVaultDialogs.toggleRoomHiddenWithAuth(
                          context,
                          ref,
                          roomId: widget.roomId,
                          chatName: widget.chatName,
                        ),
                      ),
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: MekaarCardDivider(fullWidth: true),
                ),

                // Tindakan
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tindakan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: MekaarColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

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

                // Blokir
                ListTile(
                  leading: Icon(
                    SolarIconsOutline.dangerTriangle,
                    color: _isBlocked ? MekaarColors.guardianTeal : MekaarColors.sosCoral,
                  ),
                  title: Text(_isBlocked ? 'Buka Blokir Kontak' : 'Blokir Kontak'),
                  onTap: _toggleBlock,
                ),

                // Laporkan Pengguna
                ListTile(
                  leading: const Icon(SolarIconsOutline.flag, color: MekaarColors.warnAmber),
                  title: const Text('Laporkan Pengguna'),
                  onTap: _showReportDialog,
                ),
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: MekaarColors.warnAmber),
      title: Text(title, style: MekaarTypography.labelLG),
      subtitle: Text(subtitle, style: MekaarTypography.bodySM),
      value: value,
      activeTrackColor: MekaarColors.guardianTeal,
      onChanged: onChanged,
    );
  }

  Widget _buildDisappearingTile() {
    final effectiveHours = _disappearingOverrideHours ?? 0;
    final isDisappearingActive = effectiveHours > 0;
    final label = _formatDuration(effectiveHours);

    return ListTile(
      leading: Icon(
        isDisappearingActive
            ? SolarIconsBold.history
            : SolarIconsOutline.clockCircle,
        color: isDisappearingActive
            ? MekaarColors.softCoral
            : MekaarColors.textPrimaryOf(context),
      ),
      title: const Text('Pesan Menghilang'),
      subtitle: Text(
        label,
        style: MekaarTypography.bodySM.copyWith(
          color: isDisappearingActive
              ? MekaarColors.softCoral
              : MekaarColors.textSecondaryOf(context),
        ),
      ),
      trailing: const Icon(
        SolarIconsOutline.altArrowRight,
        size: 18,
        color: MekaarColors.textMuted,
      ),
      onTap: () => _showDisappearingPicker(),
    );
  }

  void _showDisappearingPicker() {
    final currentEffective = _disappearingOverrideHours ?? 0;

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: MekaarColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pesan Menghilang Chat Ini', style: MekaarTypography.headingSM),
            const SizedBox(height: 4),
            Text(
              'Atur berapa lama pesan baru otomatis terhapus untuk obrolan ini.',
              style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMuted),
            ),
            const SizedBox(height: 16),
            _pickerOption(ctx, 'Nonaktif', 0, currentEffective == 0),
            _pickerOption(ctx, '1 Jam', 1, currentEffective == 1),
            _pickerOption(ctx, '24 Jam', 24, currentEffective == 24),
            _pickerOption(ctx, '7 Hari', 168, currentEffective == 168),
            _pickerOption(ctx, '30 Hari', 720, currentEffective == 720),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(BuildContext ctx, String label, int? hours, bool selected) {
    return ListTile(
      title: Text(label, style: MekaarTypography.labelLG),
      trailing: selected ? const Icon(SolarIconsOutline.checkCircle, color: MekaarColors.guardianTeal) : null,
      onTap: () {
        Navigator.pop(ctx);
        _setDisappearing(hours);
      },
    );
  }

  String _formatDuration(int hours) {
    if (hours <= 0) return 'Nonaktif';
    if (hours < 24) return '$hours jam';
    if (hours < 168) return '${hours ~/ 24} hari';
    return '${hours ~/ 24} hari';
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
      MekaarSnackbar.warning(context, 'Alasan laporan wajib diisi');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final repo = ReportRepository(ref.read(supabaseServiceProvider));
      await repo.submitReport(
        reportedUserId: widget.otherUserId,
        roomId: widget.roomId,
        category: _selectedCategory,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      MekaarSnackbar.success(
        context,
        'Laporan Anda telah berhasil dikirim ke tim Moderasi',
      );
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal mengirim laporan: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MekaarColors.surface2Of(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(
            SolarIconsBold.shieldWarning,
            color: MekaarColors.warnAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text('Laporkan Pengguna', style: MekaarTypography.headingSM),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih kategori pelanggaran:', style: MekaarTypography.labelMD),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              isExpanded: true,
              dropdownColor: MekaarColors.surface2Of(context),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'spam', child: Text('Spamming / Bot')),
                DropdownMenuItem(value: 'harassment', child: Text('Pelecehan / Ancaman')),
                DropdownMenuItem(value: 'fake_sos', child: Text('Penyalahgunaan Fitur Darurat SOS')),
                DropdownMenuItem(value: 'impersonation', child: Text('Akun Palsu / Penyamaran')),
                DropdownMenuItem(value: 'other', child: Text('Lainnya')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            Text('Alasan & Detail Laporan:', style: MekaarTypography.labelMD),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Jelaskan indikasi pelanggaran yang dilakukan...',
                border: OutlineInputBorder(),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kirim Laporan'),
        ),
      ],
    );
  }
}
