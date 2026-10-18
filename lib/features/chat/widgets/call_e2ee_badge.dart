import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/call_e2ee_helper.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';

/// Lencana interaktif E2EE (End-to-End Encryption) bergaya 4 emoji ala Telegram
/// untuk memverifikasi keamanan dan integritas panggilan WebRTC.
class CallE2eeBadge extends StatelessWidget {
  final String callId;
  final String myUserId;
  final String remoteUserId;
  final String chatName;
  final String? sdpFingerprint;

  const CallE2eeBadge({
    super.key,
    required this.callId,
    required this.myUserId,
    required this.remoteUserId,
    required this.chatName,
    this.sdpFingerprint,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = CallE2eeHelper.getCallEmojis(
      callId: callId,
      userId1: myUserId,
      userId2: remoteUserId,
      sdpFingerprint: sdpFingerprint,
    );

    return Semantics(
      label: 'Verifikasi enkripsi end-to-end panggilan',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showE2eeModal(context, emojis),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsOutline.lock,
                  size: 13,
                  color: MekaarColors.safeTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  emojis.join(' '),
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showE2eeModal(BuildContext context, List<String> emojis) {
    HapticService.trigger(MekaarHapticIntent.selection);
    MekaarBottomSheet.show(
      context: context,
      title: 'Enkripsi End-to-End Panggilan',
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MekaarColors.safeTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  SolarIconsBold.shieldCheck,
                  size: 40,
                  color: MekaarColors.safeTeal,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: MekaarColors.surfaceOf(ctx),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MekaarColors.dividerOf(ctx),
                    width: 1,
                  ),
                ),
                child: Text(
                  emojis.join('   '),
                  style: const TextStyle(
                    fontSize: 32,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Panggilan ini dilindungi enkripsi end-to-end langsung antar-perangkat (WebRTC DTLS-SRTP). '
                'Pihak ketiga—bahkan server Mekaar sekalipun—tidak dapat mendengar atau melihat percakapan ini.',
                textAlign: TextAlign.center,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textSecondaryOf(ctx),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Jika 4 emoji di atas persis sama dengan yang tampil di layar $chatName, sambungan Anda terbukti 100% otentik dan bebas penyadapan.',
                textAlign: TextAlign.center,
                style: MekaarTypography.bodySM.copyWith(
                  fontWeight: FontWeight.w600,
                  color: MekaarColors.textPrimaryOf(ctx),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
