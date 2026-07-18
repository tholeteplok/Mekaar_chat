import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/custom_card.dart';
import '../providers/guardian_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../../../data/models/guardian_model.dart';

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
  late String _storageOption;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _gpsEnabled = widget.guardian.permissions['gps'] ?? false;
    _micEnabled = widget.guardian.permissions['mic'] ?? false;
    _videoEnabled = widget.guardian.permissions['video'] ?? false;
    _storageOption = widget.guardian.storageOption;
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(guardianProvider.notifier).updateGuardianPermissions(
        widget.guardian.id,
        {'gps': _gpsEnabled, 'mic': _micEnabled, 'video': _videoEnabled},
        _storageOption,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin berhasil diperbarui.'),
            backgroundColor: MekaarColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _initiateSwap() async {
    // Navigasi ke swap screen
    Navigator.pushNamed(
      context,
      '/guardian/swap',
      arguments: {'guardian': widget.guardian},
    );
  }

  Future<void> _removeGuardian() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Guardian?'),
        content: Text(
          'Anda akan menghapus ${widget.guardian.name} dari daftar guardian. '
          'Semua izin akses akan dicabut.',
        ),
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
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(guardianProvider.notifier)
          .removeGuardian(widget.guardian.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleBlock() async {
    final guardianUserId = widget.guardian.guardianId;
    if (guardianUserId.isEmpty) return;
    final notifier = ref.read(blockProvider.notifier);
    final blocked = await ref.read(blockRepositoryProvider).isBlocked(guardianUserId);
    try {
      if (blocked) {
        await notifier.unblockUser(guardianUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardian dibuka blokirnya.'),
              backgroundColor: MekaarColors.success,
            ),
          );
        }
      } else {
        await notifier.blockUser(guardianUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardian berhasil diblokir.'),
              backgroundColor: MekaarColors.success,
            ),
          );
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.guardian.status == 'pending';
    final isExpired = widget.guardian.isExpired;

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: 'Detail Guardian',
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.trashBinMinimalistic, color: MekaarColors.sosRed),
            onPressed: _removeGuardian,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Card ──
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Avatar(
                    initial: widget.guardian.name.isNotEmpty
                        ? widget.guardian.name[0]
                        : 'U',
                    size: 56,
                    isGuardian: widget.guardian.status == 'active',
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.guardian.name,
                          style: MekaarTypography.headingSM,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.guardian.email,
                          style: MekaarTypography.bodySM,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusBadge(isPending, isExpired),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Block / Unblock ──
            FutureBuilder<bool>(
              future: ref
                  .read(blockRepositoryProvider)
                  .isBlocked(widget.guardian.guardianId),
              builder: (context, snapshot) {
                final isBlocked = snapshot.data ?? false;
                return CustomCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isBlocked
                          ? SolarIconsOutline.userBlock
                          : SolarIconsOutline.userMinus,
                      color: isBlocked
                          ? MekaarColors.sosRed
                          : MekaarColors.textSecondary,
                    ),
                    title: Text(
                      isBlocked ? 'Buka Blokir Guardian' : 'Blokir Guardian',
                      style: MekaarTypography.labelLG.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? MekaarColors.sosRed : null,
                      ),
                    ),
                    subtitle: Text(
                      isBlocked
                          ? 'Izinkan guardian ini menghubungi Anda kembali.'
                          : 'Hentikan guardian ini mengirim pesan atau undangan.',
                      style: MekaarTypography.bodySM,
                    ),
                    onTap: _toggleBlock,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Expiry Info ──
            if (!isPending && !isExpired)
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MekaarColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        SolarIconsOutline.stopwatch,
                        color: MekaarColors.success,
                        size: 20,
                      ),
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

            if (isExpired)
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MekaarColors.sosLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        SolarIconsOutline.danger,
                        color: MekaarColors.sosRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Izin guardian ini sudah kadaluarsa. Simpan ulang untuk mengaktifkan kembali.',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.sosRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // ── Permissions Section ──
            Text(
              'IZIN KEAMANAN (HANYA AKTIF SAAT SOS)',
              style: MekaarTypography.overline,
            ),
            const SizedBox(height: 12),
            CustomCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: MekaarColors.softCoral,
                    secondary: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _gpsEnabled
                            ? MekaarColors.infoLight
                            : MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        SolarIconsOutline.mapPoint,
                        color: _gpsEnabled
                            ? MekaarColors.info
                            : MekaarColors.textMuted,
                        size: 20,
                      ),
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
                    onChanged: (v) => setState(() => _gpsEnabled = v),
                  ),
                  const Divider(
                    height: 1,
                    color: MekaarColors.borderLight,
                    indent: 72,
                  ),
                  SwitchListTile(
                    activeThumbColor: MekaarColors.softCoral,
                    secondary: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _micEnabled
                            ? MekaarColors.guardianLight
                            : MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        SolarIconsOutline.microphone,
                        color: _micEnabled
                            ? MekaarColors.guardianTeal
                            : MekaarColors.textMuted,
                        size: 20,
                      ),
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
                    onChanged: (v) => setState(() => _micEnabled = v),
                  ),
                  const Divider(
                    height: 1,
                    color: MekaarColors.borderLight,
                    indent: 72,
                  ),
                  SwitchListTile(
                    activeThumbColor: MekaarColors.softCoral,
                    secondary: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _videoEnabled
                            ? MekaarColors.guardianLight
                            : MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        SolarIconsOutline.videocamera,
                        color: _videoEnabled
                            ? MekaarColors.guardianTeal
                            : MekaarColors.textMuted,
                        size: 20,
                      ),
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
                    onChanged: (v) => setState(() => _videoEnabled = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Storage Option Section ──
            Text('OPSI PENYIMPANAN REKAMAN', style: MekaarTypography.overline),
            const SizedBox(height: 12),
            _buildStorageOptions(),

            const SizedBox(height: 32),

            // ── Actions ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Simpan Perubahan',
                        style: MekaarTypography.buttonLG.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(
                  SolarIconsOutline.refresh,
                  color: MekaarColors.guardianTeal,
                ),
                label: Text(
                  'Tukar Posisi (Saling Menjaga)',
                  style: MekaarTypography.buttonMD.copyWith(
                    color: MekaarColors.guardianTeal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: MekaarColors.guardianTeal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _initiateSwap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPending, bool isExpired) {
    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MekaarColors.warningLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Menunggu Persetujuan',
          style: MekaarTypography.labelSM.copyWith(color: MekaarColors.warning),
        ),
      );
    } else if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MekaarColors.sosLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Kadaluarsa',
          style: MekaarTypography.labelSM.copyWith(color: MekaarColors.sosRed),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MekaarColors.successLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Aktif',
        style: MekaarTypography.labelSM.copyWith(color: MekaarColors.success),
      ),
    );
  }

  Widget _buildStorageOptions() {
    final options = [
      {
        'value': 'stream_only',
        'label': 'Streaming Saja',
        'desc': 'Tidak ada data yang disimpan.',
        'icon': SolarIconsOutline.soundwave,
      },
      {
        'value': 'server',
        'label': 'Server Terenkripsi',
        'desc': 'Guardian bisa putar ulang, tidak bisa unduh.',
        'icon': SolarIconsOutline.cloud,
      },
      {
        'value': 'drive_a',
        'label': 'Drive Pribadi Saya',
        'desc': 'File langsung ke Google Drive/iCloud Anda.',
        'icon': SolarIconsOutline.folderWithFiles,
      },
      {
        'value': 'drive_link',
        'label': 'Drive + Tautan Sementara',
        'desc': 'Guardian dapat tautan 24 jam, tidak permanen.',
        'icon': SolarIconsOutline.link,
      },
    ];

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final opt = entry.value;
          final isSelected = _storageOption == opt['value'];
          final isLast = index == options.length - 1;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MekaarColors.softCoral.withValues(alpha: 0.1)
                        : MekaarColors.surface2Of(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    opt['icon'] as IconData,
                    color: isSelected
                        ? MekaarColors.softCoral
                        : MekaarColors.textMuted,
                    size: 18,
                  ),
                ),
                title: Text(
                  opt['label'] as String,
                  style: MekaarTypography.labelLG,
                ),
                subtitle: Text(
                  opt['desc'] as String,
                  style: MekaarTypography.bodySM,
                ),
                trailing: isSelected
                    ? const Icon(
                        SolarIconsBold.checkCircle,
                        color: MekaarColors.softCoral,
                      )
                    : const Icon(
                        SolarIconsOutline.checkCircle,
                        color: MekaarColors.textMuted,
                      ),
                onTap: () =>
                    setState(() => _storageOption = opt['value'] as String),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  color: MekaarColors.borderLight,
                  indent: 72,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
