import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/guardian_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddGuardianScreen extends ConsumerStatefulWidget {
  const AddGuardianScreen({super.key});

  @override
  ConsumerState<AddGuardianScreen> createState() => _AddGuardianScreenState();
}

class _AddGuardianScreenState extends ConsumerState<AddGuardianScreen> {
  final _searchController = TextEditingController();
  bool _gpsPermission = true;
  bool _audioPermission = false;
  bool _videoPermission = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitInvitation() async {
    final query = _searchController.text.trim();
    final validationError = MekaarValidators.username(query);
    if (validationError != null) {
      MekaarSnackbar.error(context, validationError);
      return;
    }

    // Tampilkan peringatan etis sebelum kirim undangan (spec 8.4)
    final confirmed = await MekaarDialog.showConfirmation<bool>(
      context: context,
      icon: const Icon(
        SolarIconsOutline.infoCircle,
        color: MekaarColors.guardianTeal,
      ),
      title: 'Catatan Penting',
      message:
          'Dengan menambahkan Guardian, Anda memberikan izin kepada orang ini untuk memantau keberadaan Anda HANYA saat Anda mengaktifkan tombol SOS.\n\n'
          'Guardian TIDAK BISA memantau Anda secara diam-diam. Akses hanya tersedia saat SOS aktif dan tercatat di Riwayat SOS.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Saya Mengerti, Kirim',
            style: TextStyle(
              color: MekaarColors.softCoral,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Cegah mengundang pengguna yang telah diblokir.
      final targetProfile = await ref
          .read(guardianRepositoryProvider)
          .searchProfile(query);
      if (targetProfile != null) {
        final targetId = targetProfile['id'] as String;
        final myId = ref.read(supabaseServiceProvider).currentUserId;
        if (targetId != myId) {
          final blocked = await ref
              .read(blockRepositoryProvider)
              .isBlocked(targetId);
          if (blocked) {
            setState(() => _isLoading = false);

            if (mounted) {
              MekaarSnackbar.error(
                context,
                'Tidak bisa menjadikan guardian pengguna yang diblokir.',
              );
            }
            return;
          }
        }
      }

      final perms = {
        'gps': _gpsPermission,
        'mic': _audioPermission,
        'video': _videoPermission,
      };

      await ref.read(guardianProvider.notifier).inviteGuardian(query, perms);

      setState(() => _isLoading = false);

      if (mounted) {
        MekaarSnackbar.success(context, 'Undangan Guardian berhasil dikirim!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mengirim undangan: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Undang Guardian'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cari Calon Guardian',
              style: MekaarTypography.headingSM,
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan username teman terpercaya yang ingin Anda undang.',
              style: MekaarTypography.bodySM,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Username',
                prefixIcon: Icon(SolarIconsOutline.magnifier),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.guardianQrScan);
                    },
                    icon: const Icon(SolarIconsOutline.qrCode, size: 18),
                    label: const Text('Pindai QR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.guardianQrInvite);
                    },
                    icon: const Icon(SolarIconsOutline.share, size: 18),
                    label: const Text('QR Saya'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Izin Keamanan (Hanya Aktif Saat SOS)',
              style: MekaarTypography.headingSM,
            ),
            const SizedBox(height: 8),
            Text(
              'Izin ini hanya berlaku jika Anda mengaktifkan tombol darurat SOS.',
              style: MekaarTypography.bodySM,
            ),
            const SizedBox(height: 20),
            // GPS permission switch
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Lacak Lokasi (GPS)',
                style: MekaarTypography.labelLG,
              ),
              subtitle: const Text(
                'Guardian dapat melihat koordinat GPS real-time Anda.',
              ),
              value: _gpsPermission,
              onChanged: (value) => setState(() => _gpsPermission = value),
            ),
            const Divider(color: MekaarColors.borderLight),
            // Audio permission switch
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Akses Mikrofon (Audio)',
                style: MekaarTypography.labelLG,
              ),
              subtitle: const Text(
                'Guardian dapat mendengar streaming suara di sekitar perangkat.',
              ),
              value: _audioPermission,
              onChanged: (value) => setState(() => _audioPermission = value),
            ),
            const Divider(color: MekaarColors.borderLight),
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Akses Kamera (Video Darurat)',
                style: MekaarTypography.labelLG,
              ),
              subtitle: const Text(
                'Anda dapat mengirim video darurat ke guardian saat SOS.',
              ),
              value: _videoPermission,
              onChanged: (value) => setState(() => _videoPermission = value),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Kirim Undangan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
