import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/bounce_interactive.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';

/// Model hasil dari [ScheduledWipeBottomSheet]
class ScheduledWipeResult {
  final String mode; // 'off' | 'one_shot' | 'daily'
  final TimeOfDay? time;
  final DateTime? targetAtUtc;

  const ScheduledWipeResult({
    required this.mode,
    this.time,
    this.targetAtUtc,
  });
}

/// Modal Bottom Sheet untuk mengatur Pembersihan Terjadwal Berbasis Jam
class ScheduledWipeBottomSheet extends StatefulWidget {
  final String initialMode;
  final TimeOfDay? initialTime;
  final DateTime? initialTargetAt;

  const ScheduledWipeBottomSheet({
    super.key,
    this.initialMode = 'off',
    this.initialTime,
    this.initialTargetAt,
  });

  static Future<ScheduledWipeResult?> show({
    required BuildContext context,
    String initialMode = 'off',
    TimeOfDay? initialTime,
    DateTime? initialTargetAt,
  }) {
    return MekaarBottomSheet.show<ScheduledWipeResult>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ScheduledWipeBottomSheet(
        initialMode: initialMode,
        initialTime: initialTime,
        initialTargetAt: initialTargetAt,
      ),
    );
  }

  @override
  State<ScheduledWipeBottomSheet> createState() => _ScheduledWipeBottomSheetState();
}

class _ScheduledWipeBottomSheetState extends State<ScheduledWipeBottomSheet> {
  late String _selectedMode;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _selectedTime = widget.initialTime ?? const TimeOfDay(hour: 14, minute: 0);
  }

  /// Menghitung target DateTime lokal & UTC berdasarkan TimeOfDay yang dipilih
  DateTime _calculateTargetDateTime(TimeOfDay time) {
    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Jika waktu target sama persis atau sudah lewat saat ini, jadwalkan ke hari esok
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickTime() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'PILIH JAM PEMBERSIHAN CHAT',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.lg),
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        if (_selectedMode == 'off') {
          _selectedMode = 'one_shot'; // Otomatis aktifkan saat user memilih jam
        }
      });
    }
  }

  void _onSave() {
    HapticService.trigger(MekaarHapticIntent.success);
    if (_selectedMode == 'off') {
      Navigator.pop(
        context,
        const ScheduledWipeResult(mode: 'off'),
      );
      return;
    }

    final targetLocal = _calculateTargetDateTime(_selectedTime);
    final targetUtc = targetLocal.toUtc();

    Navigator.pop(
      context,
      ScheduledWipeResult(
        mode: _selectedMode,
        time: _selectedTime,
        targetAtUtc: targetUtc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandAccent = MekaarColors.accentOf(context);
    final targetLocal = _calculateTargetDateTime(_selectedTime);
    final isToday = targetLocal.day == DateTime.now().day;

    return MekaarBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Judul
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  SolarIconsBold.clockCircle,
                  color: brandAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembersihan Terjadwal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hapus seluruh pesan room pada jam tertentu',
                      style: TextStyle(
                        fontSize: 13,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Card Pemilih Jam (Time Display & Selector)
          BounceInteractive(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(MekaarRadius.md),
                border: Border.all(
                  color: _selectedMode != 'off'
                      ? brandAccent.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: _selectedMode != 'off' ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Target Eksekusi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeOfDay(_selectedTime),
                        style: MekaarTypography.monoLG.copyWith(
                          fontSize: 32,
                          color: _selectedMode != 'off'
                              ? brandAccent
                              : MekaarColors.textPrimaryOf(context),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: brandAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(MekaarRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          SolarIconsOutline.pen2,
                          size: 16,
                          color: brandAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ubah Jam',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pilihan Mode (Radio Options)
          _buildModeOption(
            mode: 'off',
            title: 'Mati (Dinonaktifkan)',
            subtitle: 'Pesan tidak dihapus secara terjadwal',
            icon: SolarIconsOutline.closeCircle,
            brandAccent: brandAccent,
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            mode: 'one_shot',
            title: 'Satu Kali Saja (One-Shot)',
            subtitle: _selectedMode == 'one_shot'
                ? 'Hapus seluruh chat pada ${isToday ? "Hari Ini" : "Besok"} pukul ${_formatTimeOfDay(_selectedTime)}'
                : 'Hapus seluruh chat satu kali saat jam tercapai',
            icon: SolarIconsOutline.fire,
            brandAccent: brandAccent,
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            mode: 'daily',
            title: 'Rutin Setiap Hari (Daily)',
            subtitle: 'Hapus seluruh riwayat chat setiap hari pukul ${_formatTimeOfDay(_selectedTime)}',
            icon: SolarIconsOutline.restart,
            brandAccent: brandAccent,
          ),
          const SizedBox(height: 24),

          // Tombol Simpan
          ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.pill),
              ),
              elevation: 4,
            ),
            child: const Text(
              'Simpan Pengaturan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color brandAccent,
  }) {
    final isSelected = _selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BounceInteractive(
      onTap: () {
        HapticService.trigger(MekaarHapticIntent.selection);
        setState(() => _selectedMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? brandAccent.withValues(alpha: isDark ? 0.16 : 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          border: Border.all(
            color: isSelected
                ? brandAccent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? brandAccent
                  : MekaarColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
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
    );
  }
}
