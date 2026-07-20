import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../providers/chat_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ContactQrScanScreen extends ConsumerStatefulWidget {
  const ContactQrScanScreen({super.key});

  @override
  ConsumerState<ContactQrScanScreen> createState() => _ContactQrScanScreenState();
}

class _ContactQrScanScreenState extends ConsumerState<ContactQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractUserId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    const prefix = 'mekaar://user/';
    if (value.startsWith(prefix)) {
      final userId = value.substring(prefix.length).trim();
      return userId.isNotEmpty ? userId : null;
    }
    return null;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null) return;

    final userId = _extractUserId(raw);
    if (userId == null) return;

    final myId = ref.read(supabaseServiceProvider).currentUserId;
    if (userId == myId) {
      _showError('Tidak bisa memulai chat dengan diri sendiri.');
      return;
    }

    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      // 1. Cari profil target
      final profile = await ref
          .read(chatRepositoryProvider)
          .searchProfileById(userId);

      if (!mounted) return;

      if (profile == null) {
        _showError('Pengguna tidak ditemukan.');
        _resumeScanner();
        return;
      }

      // 2. Cek apakah diblokir
      final isBlocked = await ref
          .read(blockRepositoryProvider)
          .isBlocked(userId);

      if (!mounted) return;

      if (isBlocked) {
        _showError('Pengguna ini telah Anda blokir.');
        _resumeScanner();
        return;
      }

      // 3. Buat atau dapatkan room chat personal
      final roomId = await ref
          .read(chatRoomsProvider.notifier)
          .getOrCreateRoom(userId, 'normal');

      if (mounted) {
        Navigator.pop(context); // Tutup scanner
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.chat,
          arguments: {
            'chatId': roomId,
            'chatName': profile['full_name'] as String? ??
                profile['username'] as String? ??
                'User',
            'chatAvatar': (profile['full_name'] as String? ??
                profile['username'] as String? ??
                'U')[0],
            'isGuardian': false,
            'otherUserId': userId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal memproses QR Code: $e');
        _resumeScanner();
      }
    }
  }

  void _resumeScanner() {
    setState(() => _isProcessing = false);
    _controller.start();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MekaarColors.sosRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Pindai QR Kontak'),
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
              'Arahkan kamera ke kode QR profil teman Anda untuk memulai obrolan.',
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
