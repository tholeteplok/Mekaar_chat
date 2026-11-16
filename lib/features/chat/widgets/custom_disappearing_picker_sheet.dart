import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/disappearing_time_helper.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';

/// Modal Bottom Sheet sentral untuk memilih waktu kustom pesan menghilang
/// dengan pilihan satuan (Menit, Jam, Hari) dan rekomendasi chip cepat.
class CustomDisappearingPickerSheet extends StatefulWidget {
  final int initialMinutes;

  const CustomDisappearingPickerSheet({
    super.key,
    required this.initialMinutes,
  });

  static Future<int?> show({
    required BuildContext context,
    required int initialMinutes,
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    return MekaarBottomSheet.show<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => CustomDisappearingPickerSheet(
        initialMinutes: initialMinutes,
      ),
    );
  }

  @override
  State<CustomDisappearingPickerSheet> createState() =>
      _CustomDisappearingPickerSheetState();
}

class _CustomDisappearingPickerSheetState
    extends State<CustomDisappearingPickerSheet> {
  late DisappearingUnit _unit;
  late int _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.initialMinutes > 0) {
      final duration =
          DisappearingDuration.fromMinutes(widget.initialMinutes);
      _unit = duration.unit;
      _value = duration.value > 0 ? duration.value : 15;
    } else {
      _unit = DisappearingUnit.minute;
      _value = 15;
    }
    _controller = TextEditingController(text: _value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncText() {
    _controller.text = _value.toString();
  }

  void _onUnitChanged(int index) {
    if (index == _unit.index) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _unit = DisappearingUnit.values[index];
      _value = DisappearingTimeHelper.clampValue(_value, _unit);
      _syncText();
    });
  }

  void _updateValue(int newValue) {
    final clamped = DisappearingTimeHelper.clampValue(newValue, _unit);
    if (clamped != _value) {
      HapticService.trigger(MekaarHapticIntent.selection);
      setState(() {
        _value = clamped;
        _syncText();
      });
    }
  }

  int get _calculatedMinutes => DisappearingDuration(_value, _unit).toMinutes();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = MekaarColors.primaryOf(context);
    final surfaceColor = MekaarColors.surface2Of(context);

    return MekaarBottomSheet(
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
                  SolarIconsBold.hourglass,
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
                      'Kustom Pesan Menghilang',
                      style: MekaarTypography.headingMD.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Pilih durasi waktu sebelum pesan otomatis terhapus',
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

          // 1. Segmented Control Pilihan Satuan (Menit / Jam / Hari)
          MekaarSlidingSegmentBar(
            tabs: const ['Menit', 'Jam', 'Hari'],
            selectedIndex: _unit.index,
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
                  color: _value > 1 ? primaryColor : MekaarColors.textMutedOf(context),
                  iconSize: 32,
                  onPressed: _value > 1 ? () => _updateValue(_value - 1) : null,
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
                          },
                          onChanged: (txt) {
                            final parsed = int.tryParse(txt);
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                _value = DisappearingTimeHelper.clampValue(parsed, _unit);
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
                  color: _value < DisappearingTimeHelper.maxFor(_unit)
                      ? primaryColor
                      : MekaarColors.textMutedOf(context),
                  iconSize: 32,
                  onPressed: _value < DisappearingTimeHelper.maxFor(_unit)
                      ? () => _updateValue(_value + 1)
                      : null,
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
            children: DisappearingTimeHelper.quickPresetsFor(_unit).map((preset) {
              final isSelected = _value == preset;
              return ActionChip(
                label: Text(
                  '$preset ${_unit.label}',
                  style: MekaarTypography.labelSM.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : MekaarColors.textSecondaryOf(context),
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
                    DisappearingTimeHelper.descriptionFor(_calculatedMinutes),
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
                    'Batal',
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
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(context, _calculatedMinutes);
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
                    'Terapkan Durasi',
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
