import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';

final tripsProvider = FutureProvider.autoDispose<List<UserTrip>>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getUserTrips();
});

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsProvider);

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: 'Auto Check-In Rute',
        actions: [
          IconButton(
            icon: const Icon(SolarIconsBold.addCircle, color: MekaarColors.cyan),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.addTrip);
              ref.invalidate(tripsProvider);
            },
          ),
        ],
      ),
      body: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return MekaarStateView(
              pose: MikaPose.pin,
              title: 'Belum Ada Rute Perjalanan',
              message: 'Tambahkan rute perjalanan (contoh: Pulang Kerja) untuk mengabari Guardian secara otomatis saat Anda tiba di tujuan.',
              actionLabel: 'Tambah Rute Baru',
              onAction: () async {
                await Navigator.pushNamed(context, AppRoutes.addTrip);
                ref.invalidate(tripsProvider);
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
                  await ref.read(tripRepositoryProvider).toggleTripActive(trip.id, val);
                  ref.invalidate(tripsProvider);
                },
                onDelete: () async {
                  await ref.read(tripRepositoryProvider).deleteTrip(trip.id);
                  ref.invalidate(tripsProvider);
                  if (context.mounted) {
                    MekaarSnackbar.success(context, 'Rute "${trip.title}" berhasil dihapus');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MekaarStateView(
          pose: MikaPose.neutral,
          title: 'Gagal Memuat Rute',
          message: err.toString(),
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(tripsProvider),
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final UserTrip trip;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _TripTile({
    required this.trip,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = MekaarColors.surfaceOf(context);

    return Container(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: trip.isActive
              ? MekaarColors.cyan.withValues(alpha: 0.3)
              : MekaarColors.surface2Of(context),
        ),
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
                  color: trip.isActive ? MekaarColors.cyan : MekaarColors.textMutedOf(context),
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
                activeTrackColor: MekaarColors.cyan,
                onChanged: onToggle,
              ),
              IconButton(
                icon: const Icon(SolarIconsOutline.trashBinMinimalistic, color: MekaarColors.sosCoral, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          if (trip.expectedTime != null) ...[
            const SizedBox(height: MekaarSpacing.xs),
            Row(
              children: [
                Icon(SolarIconsOutline.clockCircle, size: 14, color: MekaarColors.textMutedOf(context)),
                const SizedBox(width: 4),
                Text(
                  'Estimasi tiba: ${trip.expectedTime} WIB (+${trip.gracePeriodMinutes}m grace)',
                  style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
