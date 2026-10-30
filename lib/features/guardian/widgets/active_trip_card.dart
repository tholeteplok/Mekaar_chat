import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../settings/providers/trip_provider.dart';

/// Kartu persisten untuk memantau status perjalanan aktif hari ini.
///
/// Menyediakan aksi 1-ketukan "Aku Sudah Sampai" dan "+15 mnt"
/// tanpa perlu membuka menu pengaturan tersembunyi.
class ActiveTripCard extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry? margin;

  const ActiveTripCard({super.key, this.margin});

  @override
  ConsumerState<ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends ConsumerState<ActiveTripCard> {
  bool _isActionInProgress = false;

  Future<void> _confirmArrival(UserTrip trip) async {
    setState(() => _isActionInProgress = true);
    HapticService.trigger(MekaarHapticIntent.success);

    try {
      await ref.read(tripRepositoryProvider).confirmArrivalManually(trip.id);
      ref.invalidate(userTripsProvider);
      if (mounted) {
        MekaarSnackbar.success(
          context,
          'Selamat tiba di tujuan! Status perjalanan diselesaikan.',
        );
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal konfirmasi kedatangan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _snooze(UserTrip trip) async {
    setState(() => _isActionInProgress = true);
    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      await ref.read(tripRepositoryProvider).snoozeTrip(trip.id, 15);
      ref.invalidate(userTripsProvider);
      if (mounted) {
        MekaarSnackbar.info(
          context,
          'Waktu kedatangan diperpanjang +15 menit.',
        );
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menunda perjalanan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripTodayProvider);
    if (trip == null) return const SizedBox.shrink();

    final status = trip.effectiveStatus;
    final isSnoozed = status == TripStatus.snoozed;
    final isDelayed = status == TripStatus.delayedWarned;

    Color accentColor;
    String statusBadge;
    if (isDelayed) {
      accentColor = MekaarColors.warnAmber;
      statusBadge = 'Menunggu Konfirmasi';
    } else if (isSnoozed) {
      accentColor = MekaarColors.info;
      statusBadge = 'Ditunda +15m';
    } else {
      accentColor = AppColors.blue;
      statusBadge = 'Sedang Berjalan';
    }

    return CustomCard(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      border: Border.all(
        color: accentColor.withValues(alpha: 0.35),
        width: 1.2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  SolarIconsOutline.mapPointWave,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: MekaarTypography.labelLG.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tujuan: ${trip.destinationZone.label} · ETA: ${trip.expectedTime ?? "-"}',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusBadge,
                  style: MekaarTypography.caption.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Tombol Tambah Waktu (+15 menit)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                  side: BorderSide(color: MekaarColors.cardBorderOf(context)),
                ),
                onPressed: _isActionInProgress ? null : () => _snooze(trip),
                icon: const Icon(SolarIconsOutline.clockCircle, size: 16),
                label: const Text('+15 mnt'),
              ),
              const SizedBox(width: 8),
              // Tombol Primer 1-Tap: "Aku sudah sampai"
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isActionInProgress
                      ? null
                      : () => _confirmArrival(trip),
                  icon: const Icon(SolarIconsOutline.checkCircle, size: 18),
                  label: Text(
                    'Aku Sudah Sampai',
                    style: MekaarTypography.labelMD.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
