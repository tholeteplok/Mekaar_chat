import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/guardian_model.dart';
import '../providers/guardian_provider.dart';
import '../providers/trip_permission_provider.dart';

class StartHangoutSheet extends ConsumerStatefulWidget {
  const StartHangoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (_) => const StartHangoutSheet(),
    );
  }

  @override
  ConsumerState<StartHangoutSheet> createState() => _StartHangoutSheetState();
}

class _StartHangoutSheetState extends ConsumerState<StartHangoutSheet> {
  final _destinationController = TextEditingController();
  int _selectedHours = 2;
  bool _reminder15mEnabled = true;
  Guardian? _selectedGuardian;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardians = ref.watch(guardianProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(SolarIconsOutline.mapPoint, color: MekaarColors.softCoral, size: 24),
              const SizedBox(width: 10),
              Text(
                'Mulai Sesi Hangout (Bagi Lokasi)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lokasi Anda akan dibagikan sementara ke Wali penerima secara berkala (tiap 5 menit). Anda dapat menghentikan sesi kapan saja.',
            style: TextStyle(
              fontSize: 12,
              color: MekaarColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Input Tujuan Hangout
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(
              labelText: 'Tujuan Hangout / Tempat',
              hintText: 'Mis. Mall Grand Indonesia, Cafe Kopi',
              prefixIcon: Icon(SolarIconsOutline.pointOnMap),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Durasi Hangout
          Text(
            'Durasi Pembagian Lokasi:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MekaarColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3, 5].map((hours) {
              final isSelected = _selectedHours == hours;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$hours Jam'),
                  selected: isSelected,
                  selectedColor: MekaarColors.softCoral,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedHours = hours);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              final endTime = DateTime.now().add(Duration(hours: _selectedHours));
              return Text(
                'Perkiraan selesai: ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textSecondaryOf(context),
                  fontStyle: FontStyle.italic,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Pengingat 15m Sebelum Selesai (Opsional)
          SwitchListTile(
            title: const Text('Pengingat 15 Menit Sebelum Selesai'),
            subtitle: const Text('Kirim notifikasi ke anak & wali sebelum sesi berakhir'),
            value: _reminder15mEnabled,
            activeTrackColor: MekaarColors.softCoral,
            onChanged: (val) => setState(() => _reminder15mEnabled = val),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          // 4. Pilih Wali Penerima
          if (guardians.isEmpty)
            const Text(
              'Belum ada Wali terhubung. Tambahkan Wali terlebih dahulu.',
              style: TextStyle(color: MekaarColors.sosRed, fontSize: 12),
            )
          else ...[
            DropdownButtonFormField<Guardian>(
              initialValue: _selectedGuardian ?? guardians.first,
              decoration: const InputDecoration(
                labelText: 'Pilih Wali Penerima',
                prefixIcon: Icon(SolarIconsOutline.userHeart),
              ),
              items: guardians.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(g.name.isNotEmpty ? g.name : g.guardianId),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedGuardian = val),
            ),
          ],
          const SizedBox(height: 24),

          // Tombol Mulai
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleStart,
              icon: const Icon(SolarIconsOutline.playCircle, size: 20),
              label: Text(_isSubmitting ? 'Memproses...' : 'Mulai Bagikan Lokasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.softCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStart() async {
    final dest = _destinationController.text.trim();
    if (dest.isEmpty) {
      MekaarSnackbar.error(context, 'Harap isi tujuan hangout');
      return;
    }
    final guardians = ref.read(guardianProvider);
    final guardian = _selectedGuardian ?? (guardians.isNotEmpty ? guardians.first : null);
    if (guardian == null) {
      MekaarSnackbar.error(context, 'Harap pilih wali penerima');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final endTime = DateTime.now().add(Duration(hours: _selectedHours));
      await ref.read(tripPermissionNotifierProvider.notifier).startHangout(
            guardianId: guardian.guardianId,
            destinationName: dest,
            endTime: endTime,
            pingIntervalMinutes: 5,
            reminder15mEnabled: _reminder15mEnabled,
          );

      if (!mounted) return;
      Navigator.pop(context);
      MekaarSnackbar.success(context, 'Sesi Hangout ke $dest berhasil dimulai!');
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal memulai sesi: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
