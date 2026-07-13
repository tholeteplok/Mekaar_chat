import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../providers/sos_provider.dart';

class SOSActiveScreen extends ConsumerStatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  ConsumerState<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends ConsumerState<SOSActiveScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sosProvider.notifier).activateSOS(gps: true, mic: true, video: false);
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleEndSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akhiri Mode Darurat?'),
        content: const Text(
          'Akses lokasi GPS real-time dan perekaman audio ke Guardian akan dihentikan secara total.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sosProvider.notifier).endSOS();
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close SOS Screen
              }
            },
            child: const Text(
              'Akhiri',
              style: TextStyle(color: MekaarColors.sosRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0707),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                MekaarColors.sosRed.withOpacity(0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                // Large Pulsing Visual Core
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1.0, end: 1.15),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, child) {
                    return Container(
                      width: 140 * value,
                      height: 140 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MekaarColors.sosRed.withOpacity(0.18 * (1.15 - value) / 0.15),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MekaarColors.sosRed,
                          ),
                          child: const Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                const Text(
                  'MODE DARURAT AKTIF',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Guardian Anda sedang melacak lokasi dan mendengar audio sekitar perangkat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                // Counter duration timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    _formatDuration(sosState.elapsedSeconds),
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Spacer(),
                // Actions Area
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Kirim Video ke Guardian'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: MekaarColors.sosRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/sos/video');
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Akhiri Mode Darurat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _handleEndSOS,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
