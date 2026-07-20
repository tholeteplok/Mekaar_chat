import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../providers/guardian_provider.dart';

// Layar pemindai QR: pindai kode teman → preview profil → atur izin →
// kirim undangan guardian (relasi pending, pemilik QR tetap harus accept).
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    const prefix = 'mekaar://invite/';
    if (value.startsWith(prefix)) {
      final token = value.substring(prefix.length).trim();
      return token.length >= 16 ? token : null;
    }
    // Terima juga token mentah (hasil "Salin Kode").
    return value.length >= 16 ? value : null;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null) return;

    final token = _extractToken(raw);
    if (token == null) return;

    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final profile = await ref
          .read(guardianRepositoryProvider)
          .previewInviteToken(token);
      if (!mounted) return;
      if (profile == null) {
        _showError('Kode undangan tidak valid atau sudah diperbarui.');
        return;
      }
      final sent = await _showInviteSheet(profile, token);
      if (sent == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (mounted) {
        _showError(
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: MekaarColors.sosRed),
    );
  }

  Future<bool?> _showInviteSheet(
    Map<String, dynamic> profile,
    String token,
  ) {
    bool gps = true;
    bool mic = false;
    bool video = false;
    bool sending = false;

    final name =
        profile['full_name'] as String? ??
        profile['username'] as String? ??
        'User';
    final username = profile['username'] as String? ?? '';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MekaarColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: MekaarColors.guardianTeal.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: MekaarColors.guardianTeal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: MekaarColors.textPrimary,
                              ),
                            ),
                            if (username.isNotEmpty)
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: MekaarColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Izin Keamanan (hanya aktif saat SOS Anda):',
                    style: TextStyle(
                      fontSize: 13,
                      color: MekaarColors.textSecondary,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lacak Lokasi (GPS)'),
                    value: gps,
                    onChanged: (v) => setSheetState(() => gps = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Akses Mikrofon (Audio)'),
                    value: mic,
                    onChanged: (v) => setSheetState(() => mic = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Akses Kamera (Video Darurat)'),
                    value: video,
                    onChanged: (v) => setSheetState(() => video = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              setSheetState(() => sending = true);
                              try {
                                await ref
                                    .read(guardianRepositoryProvider)
                                    .redeemInviteToken(token, {
                                      'gps': gps,
                                      'mic': mic,
                                      'video': video,
                                    });
                                await ref
                                    .read(guardianProvider.notifier)
                                    .refreshGuardians();
                                if (ctx.mounted) {
                                  Navigator.pop(ctx, true);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Undangan Guardian berhasil dikirim!',
                                      ),
                                      backgroundColor: MekaarColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => sending = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: MekaarColors.sosRed,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                        shape: const StadiumBorder(),
                      ),
                      child: sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Theme.of(ctx).colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Kirim Undangan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Pindai Kode QR'),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: MekaarColors.softCoral, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'Arahkan kamera ke kode QR milik teman terpercaya Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
          if (_isProcessing)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
