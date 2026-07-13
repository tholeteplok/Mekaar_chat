import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../providers/guardian_provider.dart';

class AddGuardianScreen extends ConsumerStatefulWidget {
  const AddGuardianScreen({super.key});

  @override
  ConsumerState<AddGuardianScreen> createState() => _AddGuardianScreenState();
}

class _AddGuardianScreenState extends ConsumerState<AddGuardianScreen> {
  final _searchController = TextEditingController();
  bool _gpsPermission = true;
  bool _audioPermission = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitInvitation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final perms = {
        'gps': _gpsPermission,
        'mic': _audioPermission,
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
            content: Text('Gagal mengirim undangan: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Undang Guardian'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cari Calon Guardian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MekaarColors.textPrimary),
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
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Izin Keamanan (Hanya Aktif Saat SOS)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MekaarColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Izin ini hanya berlaku jika Anda mengaktifkan tombol darurat SOS.',
              style: TextStyle(fontSize: 13, color: MekaarColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // GPS permission switch
            SwitchListTile(
              activeColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lacak Lokasi (GPS)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: MekaarColors.textPrimary),
              ),
              subtitle: const Text('Guardian dapat melihat koordinat GPS real-time Anda.'),
              value: _gpsPermission,
              onChanged: (value) => setState(() => _gpsPermission = value),
            ),
            const Divider(color: MekaarColors.borderLight),
            // Audio permission switch
            SwitchListTile(
              activeColor: MekaarColors.softCoral,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Akses Mikrofon (Audio)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: MekaarColors.textPrimary),
              ),
              subtitle: const Text('Guardian dapat mendengar streaming suara di sekitar perangkat.'),
              value: _audioPermission,
              onChanged: (value) => setState(() => _audioPermission = value),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Kirim Undangan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
