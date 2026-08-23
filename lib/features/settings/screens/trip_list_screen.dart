import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';
import '../providers/trip_provider.dart';
import '../widgets/settings_tiles.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(userTripsProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopBar(
              title: 'Auto Check-In Rute',
              trailing: IconButton(
                icon: const Icon(
                  SolarIconsOutline.addCircle,
                  color: MekaarColors.cyan,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: MekaarColors.surface2Of(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.addTrip);
                  ref.invalidate(userTripsProvider);
                },
              ),
            ),
            Expanded(
              child: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return MekaarStateView(
              pose: MikaPose.pin,
              title: 'Belum Ada Rute Perjalanan',
              message: 'Tambahkan rute perjalanan (contoh: Pulang Kerja) untuk mengabari Guardian secara otomatis saat Anda tiba di tujuan.',
              actionLabel: 'Tambah Rute Baru',
              onAction: () async {
                await Navigator.pushNamed(context, AppRoutes.addTrip);
                ref.invalidate(userTripsProvider);
              },
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(MekaarSpacing.md),
            itemCount: trips.length,
            separatorBuilder: (context, index) => const SizedBox(height: MekaarSpacing.sm),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _TripTile(
                trip: trip,
                onToggle: (val) async {
                  try {
                    await ref.read(tripRepositoryProvider).toggleTripActive(trip.id, val);
                    ref.invalidate(userTripsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      MekaarSnackbar.error(context, 'Gagal mengubah status rute: $e');
                    }
                  }
                },
                onManualCheckIn: () async {
                  try {
                    await ref.read(tripRepositoryProvider).confirmArrivalManually(trip.id);
                    ref.invalidate(userTripsProvider);
                    if (context.mounted) {
                      MekaarSnackbar.success(
                        context,
                        'Check-In manual untuk rute "${trip.title}" berhasil disimpan!',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      MekaarSnackbar.error(context, 'Gagal mengirim Check-In manual: $e');
                    }
                  }
                },
                onDelete: () async {
                  final confirmed = await MekaarDialog.showConfirmation<bool>(
                    context: context,
                    title: 'Hapus Rute Perjalanan?',
                    message: 'Rute "${trip.title}" akan dihapus secara permanen.',
                    isDestructive: true,
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
                            color: MekaarColors.sosCoral,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );

                  if (confirmed == true) {
                    try {
                      await ref.read(tripRepositoryProvider).deleteTrip(trip.id);
                      ref.invalidate(userTripsProvider);
                      if (context.mounted) {
                        MekaarSnackbar.success(context, 'Rute "${trip.title}" berhasil dihapus');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        MekaarSnackbar.error(context, 'Gagal menghapus rute: $e');
                      }
                    }
                  }
                },
              );
            },
          );
        },
        loading: () => const MekaarStateView(
          pose: MikaPose.pin,
          title: 'Memuat Rute',
          message: 'Sedang mengambil daftar rute perjalanan Anda...',
          layout: MekaarStateLayout.centered,
        ),
        error: (err, _) => MekaarStateView(
          pose: MikaPose.huft,
          title: 'Gagal Memuat Rute',
          message: ErrorResolver.resolve(err),
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(userTripsProvider),
        ),
      ),
    ),
  ],
),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final UserTrip trip;
  final ValueChanged<bool> onToggle;
  final VoidCallback onManualCheckIn;
  final VoidCallback onDelete;

  const _TripTile({
    required this.trip,
    required this.onToggle,
    required this.onManualCheckIn,
    required this.onDelete,
  });

  String _statusSummaryText(UserTrip trip) {
    final status = trip.effectiveStatus;
    switch (status) {
      case TripStatus.arrivedAuto:
        return 'Auto check-in berhasil (GPS) • Hari ini';
      case TripStatus.arrivedConfirmed:
        return 'Kedatangan dikonfirmasi manual • Hari ini';
      case TripStatus.delayedWarned:
        return 'Menunggu konfirmasi kedatangan Anda...';
      case TripStatus.delayedAlerted:
        return 'Peringatan keterlambatan terkirim ke Guardian';
      case TripStatus.snoozed:
        return 'Ditunda sementara (masa tunda aktif)';
      case TripStatus.scheduled:
        return trip.expectedTime != null
            ? 'Menunggu estimasi (${trip.expectedTime} WIB)'
            : 'Aktif mendeteksi geofence';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      border: Border.all(
        color: trip.isActive
            ? MekaarColors.cyan.withValues(alpha: 0.3)
            : MekaarColors.surface2Of(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: trip.isActive
                      ? MekaarColors.cyan.withValues(alpha: 0.15)
                      : MekaarColors.surface2Of(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  SolarIconsBold.mapPoint,
                  color: trip.isActive ? MekaarColors.accentTextOf(context) : MekaarColors.textMutedOf(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: MekaarSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: MekaarTypography.bodyLG.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tujuan: ${trip.destinationZone.label} (${trip.destinationZone.radiusMeters}m radius)',
                      style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: trip.isActive,
                activeThumbColor: MekaarColors.primaryOf(context),
                activeTrackColor:
                    MekaarColors.primaryOf(context).withValues(alpha: 0.35),
                inactiveThumbColor: MekaarColors.textMutedOf(context),
                inactiveTrackColor: MekaarColors.surface2Of(context),
                onChanged: onToggle,
              ),
              IconButton(
                icon: const Icon(SolarIconsOutline.trashBinMinimalistic, color: MekaarColors.sosCoral, size: 20),
                onPressed: onDelete,
                tooltip: 'Hapus Rute',
              ),
            ],
          ),
          const SizedBox(height: MekaarSpacing.xs),
          Row(
            children: [
              Icon(SolarIconsOutline.calendar, size: 14, color: MekaarColors.textMutedOf(context)),
              const SizedBox(width: 4),
              Text(
                'Hari: ${trip.activeDaysLabel}',
                style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
              ),
            ],
          ),
          if (trip.expectedTime != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(SolarIconsOutline.clockCircle, size: 14, color: MekaarColors.textMutedOf(context)),
                const SizedBox(width: 4),
                Text(
                  'Estimasi tiba: ${trip.expectedTime} WIB (tenggang ${trip.gracePeriodMinutes} menit)',
                  style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(SolarIconsOutline.infoCircle, size: 14, color: MekaarColors.accentTextOf(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _statusSummaryText(trip),
                  style: MekaarTypography.bodySM.copyWith(color: MekaarColors.accentTextOf(context), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (trip.isActive && trip.effectiveStatus == TripStatus.scheduled) ...[
            const SizedBox(height: MekaarSpacing.sm),
            OutlinedButton.icon(
              onPressed: onManualCheckIn,
              icon: Icon(SolarIconsBold.checkCircle, size: 16, color: MekaarColors.accentTextOf(context)),
              label: const Text('Check-In Manual'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MekaarColors.accentTextOf(context),
                side: BorderSide(color: MekaarColors.accentTextOf(context).withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MekaarRadius.sm)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
