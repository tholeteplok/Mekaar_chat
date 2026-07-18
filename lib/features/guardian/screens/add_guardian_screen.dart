import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
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
    final validationError = MekaarValidators.emailOrUsername(query);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: MekaarColors.sosRed,
        ),
      );
      return;
    }

    // Tampilkan peringatan etis sebelum kirim undangan (spec 8.4)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              SolarIconsOutline.infoCircle,
              color: MekaarColors.guardianTeal,
            ),
            const SizedBox(width: 8),
            Text('Catatan Penting', style: MekaarTypography.headingSM),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dengan menambahkan Guardian, Anda memberikan izin kepada orang ini untuk memantau keberadaan Anda HANYA saat Anda mengaktifkan tombol SOS.',
              style: MekaarTypography.bodyMD,
            ),
            const SizedBox(height: 12),
            Text(
              'Guardian TIDAK BISA memantau Anda secara diam-diam. Akses hanya tersedia saat SOS aktif dan tercatat di Riwayat SOS.',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.guardianTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Saya Mengerti, Kirim',
              style: TextStyle(
                color: MekaarColors.softCoral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tidak bisa menjadikan guardian pengguna yang diblokir.',
                  ),
                  backgroundColor: MekaarColors.sosRed,
                ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Undangan Guardian berhasil dikirim!'),
            backgroundColor: MekaarColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim undangan: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: MekaarColors.sosRed,
          ),
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
            const Text(
              'Cari Calon Guardian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MekaarColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan username atau email teman terpercaya yang ingin Anda undang.',
              style: TextStyle(fontSize: 13, color: MekaarColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Email atau Username',
                prefixIcon: Icon(SolarIconsOutline.magnifier),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Izin Keamanan (Hanya Aktif Saat SOS)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MekaarColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Izin ini hanya berlaku jika Anda mengaktifkan tombol darurat SOS.',
              style: TextStyle(fontSize: 13, color: MekaarColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // GPS permission switch
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lacak Lokasi (GPS)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: MekaarColors.textPrimary,
                ),
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
              title: const Text(
                'Akses Mikrofon (Audio)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: MekaarColors.textPrimary,
                ),
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
              title: const Text(
                'Akses Kamera (Video Darurat)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: MekaarColors.textPrimary,
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
