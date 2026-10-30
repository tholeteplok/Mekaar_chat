import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/guardian_model.dart';
import '../../../data/models/saved_place_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../settings/providers/trip_provider.dart';
import '../providers/guardian_provider.dart';

/// Modal Bottom Sheet untuk inisiasi cepat rute perjalanan ("Antar Aku Pulang").
///
/// Menyediakan alur 2-ketukan instan:
/// Pilih Tempat -> Pilih ETA (15/30/45/60 mnt) -> Mulai Perjalanan.
class QuickTripSheet extends ConsumerStatefulWidget {
  const QuickTripSheet({super.key});

  /// Buka QuickTripSheet sebagai Bottom Sheet terpusat
  static Future<void> show(BuildContext context) {
    return MekaarBottomSheet.show<void>(
      context: context,
      title: 'Antar Aku Pulang',
      leading: const Icon(
        SolarIconsOutline.routing,
        color: AppColors.blue,
        size: 24,
      ),
      builder: (_) => const QuickTripSheet(),
    );
  }

  @override
  ConsumerState<QuickTripSheet> createState() => _QuickTripSheetState();
}

class _QuickTripSheetState extends ConsumerState<QuickTripSheet> {
  int _selectedEtaMinutes = 30;
  String? _selectedPlaceId;
  final Set<String> _selectedGuardianIds = {};
  bool _initializedDefaults = false;
  bool _isSubmitting = false;

  final List<int> _etaOptions = const [15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    // 1. Cek apakah ada trip yang sedang aktif
    final activeTrip = ref.watch(activeTripTodayProvider);
    if (activeTrip != null) {
      return _buildAlreadyActiveContent(activeTrip);
    }

    final placesAsync = ref.watch(savedPlacesProvider);
    final guardians = ref.watch(guardianProvider);

    // Inisialisasi default 1x saat data siap
    if (!_initializedDefaults) {
      placesAsync.whenData((places) {
        if (places.isNotEmpty && _selectedPlaceId == null) {
          if (places.containsKey('home')) {
            _selectedPlaceId = 'home';
          } else {
            _selectedPlaceId = places.keys.first;
          }
        }
      });
      if (guardians.isNotEmpty && _selectedGuardianIds.isEmpty) {
        _selectedGuardianIds.addAll(guardians.map((g) => g.guardianId));
      }
      _initializedDefaults = true;
    }

    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: _selectedEtaMinutes));
    final expectedTimeString = DateFormat('HH:mm').format(arrival);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mulai pemantauan perjalanan & auto check-in 1-ketukan ke tujuan Anda.',
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: MekaarSpacing.lg),

          // SECTION 1: Tempat Tujuan
          Text(
            'PILIH TEMPAT TUJUAN',
            style: MekaarTypography.caption.copyWith(
              color: MekaarColors.textMutedOf(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: MekaarSpacing.sm),
          placesAsync.when(
            data: (places) => _buildPlacesSection(places),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (error, stack) => _buildNoPlacesState(),
          ),
          const SizedBox(height: MekaarSpacing.lg),

          // SECTION 2: Estimasi Waktu Tiba (ETA)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERKIRAAN TIBA (ETA)',
                style: MekaarTypography.caption.copyWith(
                  color: MekaarColors.textMutedOf(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tiba ~ $expectedTimeString',
                  style: MekaarTypography.caption.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MekaarSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _etaOptions.map((minutes) {
              final isSelected = _selectedEtaMinutes == minutes;
              return ChoiceChip(
                label: Text('$minutes mnt'),
                selected: isSelected,
                selectedColor: AppColors.blue.withValues(alpha: 0.18),
                backgroundColor: MekaarColors.surface2Of(context),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.blue
                      : MekaarColors.cardBorderOf(context),
                ),
                labelStyle: MekaarTypography.labelMD.copyWith(
                  color: isSelected
                      ? AppColors.blue
                      : MekaarColors.textPrimaryOf(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    setState(() => _selectedEtaMinutes = minutes);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: MekaarSpacing.lg),

          // SECTION 3: Guardian yang Diberitahu
          Text(
            'KIRIM UPDATE KE WALI',
            style: MekaarTypography.caption.copyWith(
              color: MekaarColors.textMutedOf(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: MekaarSpacing.sm),
          _buildGuardiansSection(guardians),
          const SizedBox(height: MekaarSpacing.xl),

          // TOMBOL MULAI PERJALANAN
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
              elevation: 0,
            ),
            onPressed:
                (_isSubmitting ||
                    _selectedPlaceId == null ||
                    _selectedGuardianIds.isEmpty)
                ? null
                : () => _startTrip(placesAsync.value ?? {}),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(SolarIconsOutline.mapPointWave, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Mulai Perjalanan Sekarang',
                        style: MekaarTypography.labelLG.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: MekaarSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildPlacesSection(Map<String, SavedPlace> places) {
    if (places.isEmpty) return _buildNoPlacesState();

    return Column(
      children: places.values.map((place) {
        final isSelected = _selectedPlaceId == place.id;
        IconData icon;
        if (place.iconName == 'home' || place.id == 'home') {
          icon = SolarIconsOutline.home2;
        } else if (place.iconName == 'building' || place.id == 'office') {
          icon = SolarIconsOutline.buildings;
        } else {
          icon = SolarIconsOutline.mapPoint;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              setState(() => _selectedPlaceId = place.id);
            },
            borderRadius: BorderRadius.circular(MekaarRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.blue.withValues(alpha: 0.10)
                    : MekaarColors.surface2Of(context),
                borderRadius: BorderRadius.circular(MekaarRadius.md),
                border: Border.all(
                  color: isSelected
                      ? AppColors.blue
                      : MekaarColors.cardBorderOf(context),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? AppColors.blue
                        : MekaarColors.textSecondaryOf(context),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: MekaarTypography.labelLG.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.blue
                                : MekaarColors.textPrimaryOf(context),
                          ),
                        ),
                        if (place.address != null &&
                            place.address!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            place.address!,
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      SolarIconsOutline.checkCircle,
                      color: AppColors.blue,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoPlacesState() {
    return CustomCard(
      padding: const EdgeInsets.all(12),
      color: MekaarColors.surface2Of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                SolarIconsOutline.mapPointHospital,
                color: MekaarColors.warnAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Belum ada Tempat Tersimpan',
                  style: MekaarTypography.labelMD.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simpan lokasi Rumah atau Kantor untuk mulai perjalanan 1-ketukan.',
            style: MekaarTypography.caption.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.addTrip);
            },
            icon: const Icon(SolarIconsOutline.addCircle, size: 16),
            label: const Text('Buat Rute / Atur Tujuan'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardiansSection(List<Guardian> guardians) {
    if (guardians.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(12),
        color: MekaarColors.surface2Of(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  SolarIconsOutline.shieldWarning,
                  color: MekaarColors.warnAmber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Belum Ada Guardian',
                    style: MekaarTypography.labelMD.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan wali tepercaya agar mereka dapat memantau kedatangan Anda.',
              style: MekaarTypography.caption.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.guardianAdd);
              },
              icon: const Icon(SolarIconsOutline.userPlus, size: 16),
              label: const Text('Tambah Guardian'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: guardians.map((g) {
        final gId = g.guardianId;
        final isChecked = _selectedGuardianIds.contains(gId);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MekaarColors.surface2Of(context),
            borderRadius: BorderRadius.circular(MekaarRadius.md),
            border: Border.all(color: MekaarColors.cardBorderOf(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                child: Text(
                  g.name.isNotEmpty ? g.name[0].toUpperCase() : 'W',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.name,
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Checkbox(
                value: isChecked,
                activeColor: AppColors.blue,
                onChanged: (val) {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  setState(() {
                    if (val == true) {
                      _selectedGuardianIds.add(gId);
                    } else {
                      _selectedGuardianIds.remove(gId);
                    }
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlreadyActiveContent(UserTrip activeTrip) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MekaarBanner(
          color: AppColors.blue,
          icon: SolarIconsOutline.infoCircle,
          content: Text(
            'Perjalanan sedang berjalan: ${activeTrip.title}. Anda dapat memantau status atau konfirmasi kedatangan di beranda.',
            style: MekaarTypography.bodySM.copyWith(
              color: AppColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: MekaarSpacing.md),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MekaarRadius.md),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        const SizedBox(height: MekaarSpacing.sm),
      ],
    );
  }

  Future<void> _startTrip(Map<String, SavedPlace> places) async {
    final place = places[_selectedPlaceId];
    if (place == null) return;

    setState(() => _isSubmitting = true);
    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      final now = DateTime.now();
      final arrival = now.add(Duration(minutes: _selectedEtaMinutes));
      final expectedTime = DateFormat('HH:mm').format(arrival);

      // Midnight rollover handling: jika hari tiba berbeda dengan hari berangkat,
      // cantumkan kedua hari agar isScheduledForToday tetap lolos
      final nowDay = now.weekday;
      final arrivalDay = arrival.weekday;
      final recurrenceDays = (nowDay == arrivalDay)
          ? <int>[nowDay]
          : <int>[nowDay, arrivalDay];

      final zone = TripZone(
        label: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        radiusMeters: 150,
      );

      final tripGuardians = _selectedGuardianIds
          .map(
            (gId) => TripGuardianPermission(
              id: '',
              guardianId: gId,
              delayMinutes: 0,
            ),
          )
          .toList();

      await ref
          .read(tripRepositoryProvider)
          .createTrip(
            title: 'Perjalanan ke ${place.name}',
            originLabel: 'Lokasi Sekarang',
            destinationZone: zone,
            expectedTime: expectedTime,
            gracePeriodMinutes: 30,
            guardians: tripGuardians,
            recurrenceDays: recurrenceDays,
          );

      ref.invalidate(userTripsProvider);
      HapticService.trigger(MekaarHapticIntent.success);

      if (mounted) {
        Navigator.pop(context);
        MekaarSnackbar.success(
          context,
          'Perjalanan aktif ke ${place.name}. MEKAAR siap memantau kedatangan Anda.',
        );
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memulai perjalanan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
