import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_animated.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/notification_service.dart';

/// Layar yang terbuka saat pengguna men-tap body notifikasi konfirmasi
/// kedatangan Auto Check-In.
class TripArrivalConfirmScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripArrivalConfirmScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripArrivalConfirmScreen> createState() =>
      _TripArrivalConfirmScreenState();
}

class _TripArrivalConfirmScreenState
    extends ConsumerState<TripArrivalConfirmScreen> {
  bool _isProcessing = false;
  String? _destinationLabel;
  bool _isLoadingTrip = true;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip =
          await ref.read(tripRepositoryProvider).getTripById(widget.tripId);
      if (!mounted) return;
      setState(() {
        _destinationLabel = trip?.destinationZone.label ?? 'tujuan Anda';
        _isLoadingTrip = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destinationLabel = 'tujuan Anda';
        _isLoadingTrip = false;
      });
    }
  }

  Future<void> _confirmArrived() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(tripRepositoryProvider)
          .confirmArrivalManually(widget.tripId);
      await NotificationService.cancelTripConfirmationNotification(widget.tripId);
      if (!mounted) return;
      MekaarSnackbar.success(context, 'Kedatangan dikonfirmasi. Guardian tidak akan diberi tahu.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      MekaarSnackbar.error(context, 'Gagal menyimpan konfirmasi: $e');
    }
  }

  Future<void> _snooze(int minutes) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await ref.read(tripRepositoryProvider).snoozeTrip(widget.tripId, minutes);
      await NotificationService.cancelTripConfirmationNotification(widget.tripId);
      if (!mounted) return;
      MekaarSnackbar.success(context, 'Ditunda $minutes menit. Kami akan tanya lagi nanti.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      MekaarSnackbar.error(context, 'Gagal menunda: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Konfirmasi Kedatangan'),
      body: SafeArea(
        child: _isLoadingTrip
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MekaarSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: MekaarStateView(
                          pose: MikaPose.ask,
                          reaction: MikaReaction.ask,
                          title: 'Apakah Anda sudah sampai?',
                          message: 'Waktu perkiraan tiba Anda di '
                              '$_destinationLabel telah lewat. Konfirmasi '
                              'supaya Guardian Anda tidak menerima '
                              'peringatan keterlambatan.',
                          semanticLabel: 'Konfirmasi apakah sudah sampai di tujuan',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _confirmArrived,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.guardianTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.lg),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Ya, Saya Sudah Sampai'),
                      ),
                    ),
                    const SizedBox(height: MekaarSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : () => _snooze(15),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.lg),
                          ),
                        ),
                        child: const Text('Masih di Jalan, Tunda 15 Menit'),
                      ),
                    ),
                    const SizedBox(height: MekaarSpacing.lg),
                  ],
                ),
              ),
      ),
    );
  }
}
