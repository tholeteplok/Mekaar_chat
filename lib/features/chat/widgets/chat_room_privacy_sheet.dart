import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../widgets/scheduled_wipe_bottom_sheet.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../../../data/services/e2ee_service.dart';

/// Modal Bottom Sheet terpusat untuk kontrol privasi ruang obrolan.
/// Dapat dipanggil dari menu 3-titik di ChatRoom maupun dari Info Kontak (ContactSettingsScreen).
class ChatRoomPrivacySheet extends ConsumerStatefulWidget {
  final String roomId;
  final VoidCallback? onSettingsChanged;

  const ChatRoomPrivacySheet({
    super.key,
    required this.roomId,
    this.onSettingsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    VoidCallback? onSettingsChanged,
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    return MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ChatRoomPrivacySheet(
        roomId: roomId,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  ConsumerState<ChatRoomPrivacySheet> createState() => _ChatRoomPrivacySheetState();
}

class _ChatRoomPrivacySheetState extends ConsumerState<ChatRoomPrivacySheet> {
  int _autoDeleteHours = 0;
  String _scheduledWipeMode = 'off';
  TimeOfDay? _scheduledWipeTime;
  DateTime? _scheduledWipeTargetAt;
  bool _burnOnExit = false;
  bool _isViewOnce = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoomPreferences();
  }

  Future<void> _loadRoomPreferences() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final roomAutoDelete = await repo.getRoomDisappearingHours(widget.roomId);
      final roomBurnOnExit = await repo.getRoomBurnOnExit(widget.roomId);

      String loadedWipeMode = 'off';
      TimeOfDay? loadedWipeTime;
      DateTime? loadedWipeTarget;
      try {
        final wipeData = await repo.getRoomScheduledWipe(widget.roomId);
        if (wipeData != null) {
          loadedWipeMode = wipeData['scheduled_wipe_mode'] as String? ?? 'off';
          final timeStr = wipeData['scheduled_wipe_time'] as String?;
          final targetStr = wipeData['scheduled_wipe_target_at'] as String?;
          if (timeStr != null && timeStr.contains(':')) {
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              loadedWipeTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 14,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }
          loadedWipeTarget = targetStr != null ? DateTime.tryParse(targetStr) : null;
        }
      } catch (_) {}

      final sp = await SharedPreferences.getInstance();
      final viewOnce = sp.getBool('room_view_once_${widget.roomId}') ?? false;

      if (mounted) {
        setState(() {
          _autoDeleteHours = roomAutoDelete;
          _burnOnExit = roomBurnOnExit;
          _scheduledWipeMode = loadedWipeMode;
          _scheduledWipeTime = loadedWipeTime;
          _scheduledWipeTargetAt = loadedWipeTarget;
          _isViewOnce = viewOnce;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _autoDeleteLabel() {
    if (_autoDeleteHours <= 0) return 'Mati';
    if (_autoDeleteHours == 1) return '1 Jam';
    if (_autoDeleteHours == 24) return '1 Hari';
    if (_autoDeleteHours == 168) return '7 Hari';
    return '$_autoDeleteHours Jam';
  }

  String _scheduledWipeLabel() {
    if (_scheduledWipeMode == 'off' || _scheduledWipeTime == null) return 'Mati';
    final hour = _scheduledWipeTime!.hour.toString().padLeft(2, '0');
    final minute = _scheduledWipeTime!.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    if (_scheduledWipeMode == 'daily') return '$timeStr (Harian)';
    return '$timeStr (1x)';
  }

  Future<void> _toggleScreenProtection(bool currentValue) async {
    final next = !currentValue;
    try {
      await ref
          .read(screenProtectionControllerProvider)
          .setRoomPreference(widget.roomId, next);
      HapticService.trigger(MekaarHapticIntent.selection);
      widget.onSettingsChanged?.call();
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengubah proteksi layar: $e');
      }
    }
  }

  Future<void> _toggleForwardingProtection(bool currentValue) async {
    final next = !currentValue;
    try {
      await ref
          .read(forwardingProtectionControllerProvider)
          .setRoomPreference(widget.roomId, next);
      HapticService.trigger(MekaarHapticIntent.selection);
      widget.onSettingsChanged?.call();
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengubah proteksi penerusan: $e');
      }
    }
  }

  Future<void> _toggleViewOnce() async {
    final next = !_isViewOnce;
    setState(() => _isViewOnce = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('room_view_once_${widget.roomId}', next);
      HapticService.trigger(MekaarHapticIntent.selection);
      widget.onSettingsChanged?.call();
      if (mounted) {
        MekaarSnackbar.info(
          context,
          next
              ? 'Mode Sekali Lihat Aktif (Media akan hilang setelah dibuka).'
              : 'Mode Sekali Lihat Dinonaktifkan.',
        );
      }
    } catch (_) {}
  }

  Future<void> _showAutoDeleteOptions() async {
    final choice = await MekaarBottomSheet.show<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (1, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (24, '1 Hari', 'Pesan otomatis terhapus setelah 1 hari'),
          (168, '7 Hari', 'Pesan otomatis terhapus setelah 7 hari'),
        ];
        return MekaarBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pesan Menghilang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == _autoDeleteHours;
                return ListTile(
                  leading: Icon(
                    selected ? SolarIconsBold.history : SolarIconsOutline.history,
                    color: selected ? MekaarColors.primaryOf(context) : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? Icon(Icons.check, color: MekaarColors.primaryOf(context))
                      : null,
                  onTap: () => Navigator.pop(ctx, opt.$1),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (choice != null) {
      final previousHours = _autoDeleteHours;
      setState(() => _autoDeleteHours = choice);
      try {
        await ref
            .read(chatRepositoryProvider)
            .updateRoomDisappearingHours(widget.roomId, choice);
        HapticService.trigger(MekaarHapticIntent.selection);
        widget.onSettingsChanged?.call();
      } catch (e) {
        if (mounted) {
          setState(() => _autoDeleteHours = previousHours);
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pengaturan pesan menghilang: $e',
          );
        }
      }
    }
  }

  Future<void> _showScheduledWipeOptions() async {
    final result = await ScheduledWipeBottomSheet.show(
      context: context,
      initialMode: _scheduledWipeMode,
      initialTime: _scheduledWipeTime,
      initialTargetAt: _scheduledWipeTargetAt,
    );

    if (result != null) {
      final prevMode = _scheduledWipeMode;
      final prevTime = _scheduledWipeTime;
      final prevTarget = _scheduledWipeTargetAt;

      String? timeStr;
      if (result.time != null) {
        final h = result.time!.hour.toString().padLeft(2, '0');
        final m = result.time!.minute.toString().padLeft(2, '0');
        timeStr = '$h:$m:00';
      }

      setState(() {
        _scheduledWipeMode = result.mode;
        _scheduledWipeTime = result.time;
        _scheduledWipeTargetAt = result.targetAtUtc;
      });

      try {
        await ref.read(chatRepositoryProvider).setRoomScheduledWipe(
          roomId: widget.roomId,
          mode: result.mode,
          timeString: timeStr,
          targetAtUtc: result.targetAtUtc,
        );
        HapticService.trigger(MekaarHapticIntent.selection);
        widget.onSettingsChanged?.call();
        if (mounted) {
          MekaarSnackbar.success(
            context,
            result.mode == 'off'
                ? 'Pembersihan terjadwal dinonaktifkan'
                : 'Pembersihan terjadwal aktif pada pukul ${_scheduledWipeLabel()}',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _scheduledWipeMode = prevMode;
            _scheduledWipeTime = prevTime;
            _scheduledWipeTargetAt = prevTarget;
          });
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pembersihan terjadwal: $e',
          );
        }
      }
    }
  }

  Future<void> _toggleBurnOnExit() async {
    if (!_burnOnExit) {
      final confirmed = await MekaarDialog.showConfirmation<bool>(
        context: context,
        title: 'Aktifkan Hapus Saat Keluar?',
        message:
            'Seluruh riwayat pesan (kirim & terima) dalam ruangan ini akan otomatis terhapus seketika saat Anda meninggalkan layar obrolan.\n\nApakah Anda yakin ingin mengaktifkannya?',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktifkan'),
          ),
        ],
      );
      if (confirmed != true) return;
    }

    final newValue = !_burnOnExit;
    final prevValue = _burnOnExit;
    setState(() => _burnOnExit = newValue);

    try {
      await ref.read(chatRepositoryProvider).setRoomBurnOnExit(widget.roomId, newValue);
      HapticService.trigger(MekaarHapticIntent.selection);
      widget.onSettingsChanged?.call();
      if (mounted) {
        MekaarSnackbar.success(
          context,
          newValue
              ? 'Hapus Saat Keluar Aktif: Pesan otomatis terhapus saat Anda keluar.'
              : 'Hapus Saat Keluar Dinonaktifkan.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _burnOnExit = prevValue);
        MekaarSnackbar.error(context, 'Gagal menyimpan pengaturan: $e');
      }
    }
  }

  Future<void> _handleSyncE2eeKeys() async {
    E2eeService.instance.invalidateRoomKey(widget.roomId);
    ref.invalidate(chatMessagesProvider(widget.roomId));
    HapticService.trigger(MekaarHapticIntent.success);
    if (mounted) {
      MekaarSnackbar.success(
        context,
        'Kunci enkripsi ruangan berhasil disinkronkan ulang.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = MekaarColors.primaryOf(context);
    final screenProtectionAsync = ref.watch(roomScreenProtectionProvider(widget.roomId));
    final isScreenProtOn = screenProtectionAsync.valueOrNull?.callerEnabled ?? true;

    final forwardingProtectionAsync = ref.watch(roomForwardingProtectionProvider(widget.roomId));
    final isFwdProtOn = forwardingProtectionAsync.valueOrNull?.callerEnabled ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      SolarIconsBold.shieldKeyhole,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan Privasi Obrolan',
                          style: MekaarTypography.headingSM.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Kontrol keamanan khusus ruang obrolan ini',
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textMutedOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Section 1: Proteksi Layar & Konten
              _buildSectionHeader('PROTEKSI LAYAR & KONTEN'),
              _buildSwitchTile(
                icon: isScreenProtOn ? SolarIconsBold.shieldCheck : SolarIconsOutline.shieldCross,
                iconColor: isScreenProtOn ? primaryColor : MekaarColors.textMutedOf(context),
                title: 'Proteksi Layar & Screenshot',
                subtitle: 'Cegah tangkapan layar dan sensor tampilan di recent apps',
                value: isScreenProtOn,
                onChanged: (_) => _toggleScreenProtection(isScreenProtOn),
              ),
              _buildSwitchTile(
                icon: isFwdProtOn ? SolarIconsBold.forbiddenCircle : SolarIconsOutline.forward,
                iconColor: isFwdProtOn ? primaryColor : MekaarColors.textMutedOf(context),
                title: 'Larang Teruskan Pesan',
                subtitle: 'Pesan dari chat ini tidak dapat diteruskan ke obrolan lain',
                value: isFwdProtOn,
                onChanged: (_) => _toggleForwardingProtection(isFwdProtOn),
              ),
              _buildSwitchTile(
                icon: _isViewOnce ? SolarIconsBold.eyeClosed : SolarIconsOutline.eyeClosed,
                iconColor: _isViewOnce ? primaryColor : MekaarColors.textMutedOf(context),
                title: 'Mode Sekali Lihat Default',
                subtitle: 'Media foto/video otomatis hangus setelah dibuka sekali',
                value: _isViewOnce,
                onChanged: (_) => _toggleViewOnce(),
              ),

              // Section 2: Penghapusan Otomatis (Self-Destruct)
              _buildSectionHeader('PENGHAPUSAN OTOMATIS'),
              _buildNavTile(
                icon: _autoDeleteHours > 0 ? SolarIconsBold.history : SolarIconsOutline.history,
                iconColor: _autoDeleteHours > 0 ? primaryColor : MekaarColors.textMutedOf(context),
                title: 'Pesan Menghilang',
                subtitle: 'Hapus pesan setelah jangka waktu tertentu',
                statusText: _autoDeleteLabel(),
                onTap: _showAutoDeleteOptions,
              ),
              _buildNavTile(
                icon: _scheduledWipeMode != 'off' ? SolarIconsBold.clockCircle : SolarIconsOutline.clockCircle,
                iconColor: _scheduledWipeMode != 'off' ? primaryColor : MekaarColors.textMutedOf(context),
                title: 'Pembersihan Terjadwal',
                subtitle: 'Hapus pesan secara berkala pada jam tertentu',
                statusText: _scheduledWipeLabel(),
                onTap: _showScheduledWipeOptions,
              ),
              _buildSwitchTile(
                icon: _burnOnExit ? SolarIconsBold.fire : SolarIconsOutline.fire,
                iconColor: _burnOnExit ? MekaarColors.sosRed : MekaarColors.textMutedOf(context),
                title: 'Hapus Saat Keluar (Burn on Exit)',
                subtitle: 'Hapus seluruh percakapan seketika saat meninggalkan layar chat',
                value: _burnOnExit,
                onChanged: (_) => _toggleBurnOnExit(),
              ),

              // Section 3: Kunci Enkripsi (E2EE)
              _buildSectionHeader('KEAMANAN ENKRIPSI'),
              _buildNavTile(
                icon: SolarIconsOutline.refreshSquare,
                iconColor: primaryColor,
                title: 'Sinkronkan Kunci Enkripsi (E2EE)',
                subtitle: 'Muat ulang session keys jika terjadi kegagalan dekripsi pesan',
                onTap: _handleSyncE2eeKeys,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: MekaarColors.textMutedOf(context),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themePrimary = MekaarColors.primaryOf(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: MekaarColors.textMutedOf(context),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: themePrimary,
        activeTrackColor: themePrimary.withValues(alpha: 0.35),
        inactiveThumbColor: MekaarColors.textMutedOf(context),
        inactiveTrackColor: MekaarColors.surface2Of(context),
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? statusText,
    required VoidCallback onTap,
  }) {
    final primaryColor = MekaarColors.primaryOf(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: MekaarColors.textMutedOf(context),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusText != null)
            Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusText == 'Mati'
                    ? MekaarColors.textMutedOf(context)
                    : primaryColor,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            SolarIconsOutline.altArrowRight,
            size: 16,
            color: MekaarColors.textMutedOf(context),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
