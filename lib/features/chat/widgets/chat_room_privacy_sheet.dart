import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_camera_off_icon.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_section_header.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/utils/disappearing_time_helper.dart';
import 'custom_disappearing_picker_sheet.dart';
import '../widgets/scheduled_wipe_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';

/// Modal Bottom Sheet terpusat untuk kontrol privasi ruang obrolan.
/// Dapat dipanggil dari menu 3-titik di ChatRoom maupun dari Info Kontak (ContactSettingsScreen).
class ChatRoomPrivacySheet extends ConsumerStatefulWidget {
  final String roomId;
  final bool isGroup;
  final VoidCallback? onSettingsChanged;

  const ChatRoomPrivacySheet({
    super.key,
    required this.roomId,
    this.isGroup = false,
    this.onSettingsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    bool isGroup = false,
    VoidCallback? onSettingsChanged,
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    return MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ChatRoomPrivacySheet(
        roomId: roomId,
        isGroup: isGroup,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  ConsumerState<ChatRoomPrivacySheet> createState() => _ChatRoomPrivacySheetState();
}

class _ChatRoomPrivacySheetState extends ConsumerState<ChatRoomPrivacySheet> {
  int _autoDeleteHours = 0;
  int _autoDeleteMinutes = 0;
  String _scheduledWipeMode = 'off';
  TimeOfDay? _scheduledWipeTime;
  DateTime? _scheduledWipeTargetAt;
  bool _burnOnExit = false;
  bool _isViewOnce = false;
  bool _isLoading = true;
  bool _canManagePrivacy = true;

  @override
  void initState() {
    super.initState();
    _loadRoomPreferences();
  }

  Future<void> _loadRoomPreferences() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      if (widget.isGroup) {
        final currentUserId = ref.read(authProvider).user?.id ??
            Supabase.instance.client.auth.currentUser?.id;
        final details = await repo.getGroupDetails(widget.roomId);
        if (details != null) {
          final participants = (details['participants'] as List?) ?? [];
          String myRole = 'member';
          for (final p in participants) {
            if (p['profile_id'] == currentUserId) {
              myRole = p['role'] as String? ?? 'member';
              break;
            }
          }
          _canManagePrivacy = (myRole == 'owner' || myRole == 'admin');
        }
      }

      final roomAutoDeleteMinutes = await repo.getRoomDisappearingMinutes(widget.roomId);
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
          _autoDeleteMinutes = roomAutoDeleteMinutes;
          _autoDeleteHours = (_autoDeleteMinutes / 60).ceil();
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

  String _autoDeleteLabel() => DisappearingTimeHelper.format(_autoDeleteMinutes);

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
    final isCustomActive = _autoDeleteMinutes > 0 &&
        _autoDeleteMinutes != 60 &&
        _autoDeleteMinutes != 1440;

    final choice = await MekaarBottomSheet.show<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (60, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (1440, '24 Jam', 'Pesan otomatis terhapus setelah 24 jam'),
          (
            -1,
            'Kustom...',
            isCustomActive
                ? 'Aktif: ${_autoDeleteLabel()}'
                : 'Atur durasi menit, jam, atau hari',
          ),
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
                final bool selected;
                if (opt.$1 == -1) {
                  selected = isCustomActive;
                } else {
                  selected = opt.$1 == _autoDeleteMinutes;
                }
                return ListTile(
                  leading: Icon(
                    selected
                        ? SolarIconsBold.hourglass
                        : SolarIconsOutline.hourglass,
                    color: selected ? MekaarColors.primaryOf(context) : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? Icon(Icons.check,
                          color: MekaarColors.primaryOf(context))
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
      int? targetMinutes;
      if (choice == -1) {
        // Tampilkan Custom Duration Picker
        if (!mounted) return;
        targetMinutes = await CustomDisappearingPickerSheet.show(
          context: context,
          initialMinutes: _autoDeleteMinutes,
        );
        if (targetMinutes == null) return;
      } else {
        targetMinutes = choice;
      }

      final previousMinutes = _autoDeleteMinutes;
      final previousHours = _autoDeleteHours;
      setState(() {
        _autoDeleteMinutes = targetMinutes!;
        _autoDeleteHours = (_autoDeleteMinutes / 60).ceil();
      });
      try {
        await ref
            .read(chatRepositoryProvider)
            .updateRoomDisappearingDuration(widget.roomId, targetMinutes);
        HapticService.trigger(MekaarHapticIntent.selection);
        widget.onSettingsChanged?.call();
      } catch (e) {
        if (mounted) {
          setState(() {
            _autoDeleteMinutes = previousMinutes;
            _autoDeleteHours = previousHours;
          });
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
        title: 'Aktifkan Hapus Saat Keluar? (Kedua Pihak)',
        message:
            'Saat Anda atau rekan obrolan meninggalkan layar ini, seluruh riwayat pesan akan langsung hangus dan dimusnahkan secara permanen untuk kedua belah pihak di perangkat maupun server.\n\nApakah Anda yakin ingin mengaktifkannya?',
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
              ? 'Hapus Saat Keluar Aktif: Pesan hangus untuk kedua pihak saat layar ditutup.'
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
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    ),
                    child: Icon(
                      SolarIconsBold.incognito,
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
              if (widget.isGroup && !_canManagePrivacy)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MekaarColors.surface2Of(context),
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                    border: Border.all(
                      color: MekaarColors.borderOf(context),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        SolarIconsBold.lock,
                        size: 20,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kebijakan privasi grup ini dikelola oleh Admin.',
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Section 1: Proteksi Layar & Konten
              _buildSectionHeader('Proteksi Layar & Konten'),
              _buildSwitchTile(
                iconWidget: isScreenProtOn
                    ? MekaarCameraOffIcon(
                        size: 20,
                        color: primaryColor,
                        style: MekaarSolarIconStyle.bold,
                      )
                    : Icon(
                        SolarIconsOutline.camera,
                        color: MekaarColors.textSecondaryOf(context),
                        size: 20,
                      ),
                iconColor: primaryColor,
                title: MekaarCopy.limitScreenshotsTitle,
                subtitle: 'Blokir screenshot sistem. Lawan bicara tetap dapat memotret dengan kamera lain',
                value: isScreenProtOn,
                onChanged: _canManagePrivacy
                    ? (_) => _toggleScreenProtection(isScreenProtOn)
                    : null,
              ),
              _buildSwitchTile(
                icon: isFwdProtOn ? SolarIconsBold.forbiddenCircle : SolarIconsOutline.forward,
                iconColor: primaryColor,
                title: 'Larang Teruskan Pesan',
                subtitle: 'Pesan dari chat ini tidak dapat diteruskan ke obrolan lain',
                value: isFwdProtOn,
                onChanged: _canManagePrivacy
                    ? (_) => _toggleForwardingProtection(isFwdProtOn)
                    : null,
              ),
              _buildSwitchTile(
                icon: _isViewOnce ? SolarIconsBold.eyeClosed : SolarIconsOutline.eye,
                iconColor: primaryColor,
                title: 'Mode Sekali Lihat Default',
                subtitle: 'Media foto/video otomatis hangus setelah dibuka sekali',
                value: _isViewOnce,
                onChanged: (_) => _toggleViewOnce(),
              ),

              // Section 2: Penghapusan Otomatis
              _buildSectionHeader(
                widget.isGroup
                    ? 'Penghapusan Otomatis (Grup)'
                    : 'Penghapusan Otomatis (Kedua Pihak)',
                description: widget.isGroup
                    ? 'Fitur di bawah ini tersinkronisasi dan menghapus pesan untuk seluruh anggota grup.'
                    : 'Fitur di bawah ini tersinkronisasi dan menghapus pesan di perangkat Anda maupun rekan.',
              ),
              _buildNavTile(
                icon: _autoDeleteMinutes > 0 ? SolarIconsBold.hourglass : SolarIconsOutline.hourglass,
                iconColor: primaryColor,
                isActive: _autoDeleteMinutes > 0,
                title: 'Pesan Menghilang',
                subtitle: 'Pesan baru otomatis terhapus untuk semua pihak setelah batas waktu',
                statusText: _autoDeleteLabel(),
                onTap: _canManagePrivacy ? _showAutoDeleteOptions : null,
              ),
              _buildNavTile(
                icon: _scheduledWipeMode != 'off' ? SolarIconsBold.clockCircle : SolarIconsOutline.clockCircle,
                iconColor: primaryColor,
                isActive: _scheduledWipeMode != 'off',
                title: 'Pembersihan Terjadwal',
                subtitle: 'Musnahkan riwayat pesan grup secara berkala pada jam tertentu',
                statusText: _scheduledWipeLabel(),
                onTap: _canManagePrivacy ? _showScheduledWipeOptions : null,
              ),
              _buildSwitchTile(
                icon: _burnOnExit ? SolarIconsBold.fire : SolarIconsOutline.fire,
                iconColor: MekaarColors.sosRed,
                title: MekaarCopy.clearOnCloseTitle,
                subtitle: MekaarCopy.clearOnCloseSubtitle,
                value: _burnOnExit,
                onChanged: _canManagePrivacy ? (_) => _toggleBurnOnExit() : null,
              ),

            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? description}) {
    return MekaarSectionHeader(
      title: title,
      subtitle: description,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 6),
    );
  }

  Widget _buildSwitchTile({
    IconData? icon,
    Widget? iconWidget,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final themePrimary = MekaarColors.primaryOf(context);
    final isEffectiveActive = value && onChanged != null;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isEffectiveActive
              ? iconColor.withValues(alpha: 0.12)
              : MekaarColors.surface2Of(context),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: iconWidget ??
              Icon(
                icon,
                color: isEffectiveActive
                    ? iconColor
                    : MekaarColors.textSecondaryOf(context),
                size: 20,
              ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onChanged == null ? MekaarColors.textMutedOf(context) : null,
        ),
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
      onTap: onChanged != null ? () => onChanged(!value) : null,
    );
  }

  Widget _buildNavTile({
    IconData? icon,
    Widget? iconWidget,
    required Color iconColor,
    required bool isActive,
    required String title,
    required String subtitle,
    String? statusText,
    VoidCallback? onTap,
  }) {
    final primaryColor = MekaarColors.primaryOf(context);
    final isEffectiveActive = isActive && onTap != null;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isEffectiveActive
              ? iconColor.withValues(alpha: 0.12)
              : MekaarColors.surface2Of(context),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: iconWidget ??
              Icon(
                icon,
                color: isEffectiveActive
                    ? iconColor
                    : MekaarColors.textSecondaryOf(context),
                size: 20,
              ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onTap == null ? MekaarColors.textMutedOf(context) : null,
        ),
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
                    : (onTap == null ? MekaarColors.textMutedOf(context) : primaryColor),
              ),
            ),
          const SizedBox(width: 4),
          if (onTap == null)
            Icon(
              SolarIconsBold.lock,
              size: 16,
              color: MekaarColors.textMutedOf(context),
            )
          else
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
