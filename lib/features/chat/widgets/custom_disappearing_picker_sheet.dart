import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/utils/disappearing_time_helper.dart';
import '../../../core/widgets/mekaar_custom_duration_picker_sheet.dart';

/// Modal Bottom Sheet sentral untuk memilih waktu kustom pesan menghilang
/// dengan pilihan satuan (Menit, Jam, Hari) dan rekomendasi chip cepat.
class CustomDisappearingPickerSheet extends StatelessWidget {
  final int initialMinutes;

  const CustomDisappearingPickerSheet({
    super.key,
    required this.initialMinutes,
  });

  static DisappearingUnit _toDisappearingUnit(MekaarDurationUnit unit) {
    switch (unit) {
      case MekaarDurationUnit.minute:
        return DisappearingUnit.minute;
      case MekaarDurationUnit.hour:
        return DisappearingUnit.hour;
      case MekaarDurationUnit.day:
        return DisappearingUnit.day;
      case MekaarDurationUnit.second:
        return DisappearingUnit.minute;
    }
  }

  static Future<int?> show({
    required BuildContext context,
    required int initialMinutes,
  }) async {
    final result = await MekaarCustomDurationPickerSheet.show(
      context: context,
      title: 'Kustom Pesan Menghilang',
      subtitle: 'Pilih durasi waktu sebelum pesan otomatis terhapus',
      headerIcon: SolarIconsBold.hourglass,
      units: const [
        MekaarDurationUnit.minute,
        MekaarDurationUnit.hour,
        MekaarDurationUnit.day,
      ],
      initialDuration: Duration(
        minutes: initialMinutes > 0 ? initialMinutes : 15,
      ),
      quickPresetsFor: (unit) =>
          DisappearingTimeHelper.quickPresetsFor(_toDisappearingUnit(unit)),
      maxFor: (unit) =>
          DisappearingTimeHelper.maxFor(_toDisappearingUnit(unit)),
      descriptionBuilder: (duration) =>
          DisappearingTimeHelper.descriptionFor(duration.inMinutes),
    );
    return result?.inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return MekaarCustomDurationPickerSheet(
      title: 'Kustom Pesan Menghilang',
      subtitle: 'Pilih durasi waktu sebelum pesan otomatis terhapus',
      headerIcon: SolarIconsBold.hourglass,
      units: const [
        MekaarDurationUnit.minute,
        MekaarDurationUnit.hour,
        MekaarDurationUnit.day,
      ],
      initialDuration: Duration(
        minutes: initialMinutes > 0 ? initialMinutes : 15,
      ),
      quickPresetsFor: (unit) =>
          DisappearingTimeHelper.quickPresetsFor(_toDisappearingUnit(unit)),
      maxFor: (unit) =>
          DisappearingTimeHelper.maxFor(_toDisappearingUnit(unit)),
      descriptionBuilder: (duration) =>
          DisappearingTimeHelper.descriptionFor(duration.inMinutes),
    );
  }
}
