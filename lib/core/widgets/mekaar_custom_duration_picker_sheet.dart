import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';
import 'mekaar_sliding_segment_bar.dart';

/// Satuan waktu yang dapat dipilih pada [MekaarCustomDurationPickerSheet].
enum MekaarDurationUnit {
  second('Detik', 1),
  minute('Menit', 60),
  hour('Jam', 3600),
  day('Hari', 86400);

  final String label;
  final int secondsPerUnit;

  const MekaarDurationUnit(this.label, this.secondsPerUnit);
}

/// Komponen Bottom Sheet sentral untuk memilih durasi waktu kustom
/// (segmented tab satuan, stepper -/+, input angka, preset cepat, dan live preview).
class MekaarCustomDurationPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final List<MekaarDurationUnit> units;
  final Duration initialDuration;
  final List<int> Function(MekaarDurationUnit unit) quickPresetsFor;
  final int Function(MekaarDurationUnit unit) maxFor;
  final int Function(MekaarDurationUnit unit)? minFor;
  final String Function(Duration duration) descriptionBuilder;
  final String confirmLabel;
  final String cancelLabel;

  const MekaarCustomDurationPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.units,
    required this.initialDuration,
    required this.quickPresetsFor,
    required this.maxFor,
    required this.descriptionBuilder,
    this.minFor,
    this.confirmLabel = 'Terapkan Durasi',
    this.cancelLabel = 'Batal',
  });

  /// Menampilkan [MekaarCustomDurationPickerSheet] dan mengembalikan [Duration]
  /// yang dipilih pengguna, atau `null` jika dibatalkan.
  static Future<Duration?> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData headerIcon,
    required List<MekaarDurationUnit> units,
    required Duration initialDuration,
    required List<int> Function(MekaarDurationUnit unit) quickPresetsFor,
    required int Function(MekaarDurationUnit unit) maxFor,
    required String Function(Duration duration) descriptionBuilder,
    int Function(MekaarDurationUnit unit)? minFor,
    String confirmLabel = 'Terapkan Durasi',
    String cancelLabel = 'Batal',
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    return MekaarBottomSheet.show<Duration>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => MekaarCustomDurationPickerSheet(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        units: units,
        initialDuration: initialDuration,
        quickPresetsFor: quickPresetsFor,
        maxFor: maxFor,
        minFor: minFor,
        descriptionBuilder: descriptionBuilder,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }

  /// Memformat [Duration] menjadi teks ringkas dalam Bahasa Indonesia.
  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '0 Detik';

    if (totalSeconds % 86400 == 0) {
      return '${totalSeconds ~/ 86400} Hari';
    }
    if (totalSeconds % 3600 == 0) {
      return '${totalSeconds ~/ 3600} Jam';
    }
    if (totalSeconds % 60 == 0) {
      return '${totalSeconds ~/ 60} Menit';
    }
    if (totalSeconds < 60) {
      return '$totalSeconds Detik';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes < 60) {
      return '$minutes Menit $seconds Detik';
    }
    final hours = totalSeconds ~/ 3600;
    final remMinutes = (totalSeconds % 3600) ~/ 60;
    return remMinutes > 0 ? '$hours Jam $remMinutes Menit' : '$hours Jam';
  }

  @override
  State<MekaarCustomDurationPickerSheet> createState() =>
      _MekaarCustomDurationPickerSheetState();
}

class _MekaarCustomDurationPickerSheetState
    extends State<MekaarCustomDurationPickerSheet> {
  late MekaarDurationUnit _unit;
  late int _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _initFromDuration(widget.initialDuration);
    _controller = TextEditingController(text: _value.toString());
  }

  void _initFromDuration(Duration initial) {
    final totalSeconds = initial.inSeconds;
    // Pilih satuan terbesar yang membagi habis totalSeconds dan ada di widget.units
    final sortedUnits = [...widget.units]
      ..sort((a, b) => b.secondsPerUnit.compareTo(a.secondsPerUnit));

    if (totalSeconds > 0) {
      for (final unit in sortedUnits) {
        if (totalSeconds % unit.secondsPerUnit == 0) {
          _unit = unit;
          _value = _clampValue(totalSeconds ~/ unit.secondsPerUnit, unit);
          return;
        }
      }
    }

    // Fallback ke satuan pertama atau menit
    _unit = widget.units.contains(MekaarDurationUnit.minute)
        ? MekaarDurationUnit.minute
        : widget.units.first;
    final raw = totalSeconds > 0
        ? (totalSeconds / _unit.secondsPerUnit).round()
        : 15;
    _value = _clampValue(raw, _unit);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _minFor(MekaarDurationUnit unit) => widget.minFor?.call(unit) ?? 1;

  int _clampValue(int value, MekaarDurationUnit unit) {
    final min = _minFor(unit);
    final max = widget.maxFor(unit);
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _syncText() {
    _controller.text = _value.toString();
  }

  void _onUnitChanged(int index) {
    final newUnit = widget.units[index];
    if (newUnit == _unit) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _unit = newUnit;
      _value = _clampValue(_value, _unit);
      _syncText();
    });
  }

  void _updateValue(int newValue) {
    final clamped = _clampValue(newValue, _unit);
    if (clamped != _value) {
      HapticService.trigger(MekaarHapticIntent.selection);
      setState(() {
        _value = clamped;
        _syncText();
      });
    }
  }

  Duration get _calculatedDuration =>
      Duration(seconds: _value * _unit.secondsPerUnit);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = MekaarColors.primaryOf(context);
    final surfaceColor = MekaarColors.surface2Of(context);
    final minVal = _minFor(_unit);
    final maxVal = widget.maxFor(_unit);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  widget.headerIcon,
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
                      widget.title,
                      style: MekaarTypography.headingMD.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Segmented Control Pilihan Satuan
          MekaarSlidingSegmentBar(
            tabs: widget.units.map((u) => u.label).toList(),
            selectedIndex: widget.units.indexOf(_unit),
            onTabSelected: _onUnitChanged,
          ),
          const SizedBox(height: 20),

          // 2. Stepper & Input Angka
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(MekaarRadius.card),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(SolarIconsOutline.minusCircle),
                  color: _value > minVal
                      ? primaryColor
                      : MekaarColors.textMutedOf(context),
                  iconSize: 32,
                  onPressed:
                      _value > minVal ? () => _updateValue(_value - 1) : null,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: MekaarTypography.headingLG.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (txt) {
                            final parsed = int.tryParse(txt) ?? _value;
                            _updateValue(parsed);
                            _syncText();
                          },
                          onChanged: (txt) {
                            final parsed = int.tryParse(txt);
                            if (parsed != null && parsed >= minVal) {
                              setState(() {
                                _value = _clampValue(parsed, _unit);
                              });
                            }
                          },
                        ),
                      ),
                      Text(
                        _unit.label,
                        style: MekaarTypography.labelMD.copyWith(
                          color: MekaarColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(SolarIconsOutline.addCircle),
                  color: _value < maxVal
                      ? primaryColor
                      : MekaarColors.textMutedOf(context),
                  iconSize: 32,
                  onPressed:
                      _value < maxVal ? () => _updateValue(_value + 1) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Quick-Chips Preset Cepat (Sesuai Satuan yang Aktif)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: widget.quickPresetsFor(_unit).map((preset) {
              final isSelected = _value == preset;
              return ActionChip(
                label: Text(
                  '$preset ${_unit.label}',
                  style: MekaarTypography.labelSM.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : MekaarColors.textSecondaryOf(context),
                  ),
                ),
                backgroundColor: isSelected ? primaryColor : surfaceColor,
                side: BorderSide(
                  color: isSelected
                      ? primaryColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.pill),
                ),
                onPressed: () => _updateValue(preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // 4. Live Preview Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(MekaarRadius.base),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  SolarIconsOutline.infoCircle,
                  color: primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.descriptionBuilder(_calculatedDuration),
                    style: MekaarTypography.caption.copyWith(
                      color: primaryColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Tombol Aksi
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.pill),
                    ),
                  ),
                  child: Text(
                    widget.cancelLabel,
                    style: MekaarTypography.labelLG.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    final parsed = int.tryParse(_controller.text);
                    if (parsed != null) {
                      _value = _clampValue(parsed, _unit);
                    }
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(context, _calculatedDuration);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.accentOf(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.pill),
                    ),
                  ),
                  child: Text(
                    widget.confirmLabel,
                    style: MekaarTypography.labelLG.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
