import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// Tombol scroll-to-bottom mengambang. Muncul saat user scroll menjauh dari
/// bottom chat. Opsional menampilkan badge jumlah pesan baru.
class ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;
  final int newMessageCount;
  final bool visible;

  const ScrollToBottomButton({
    super.key,
    required this.onTap,
    this.newMessageCount = 0,
    this.visible = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: visible ? onTap : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MekaarColors.textMuted.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  SolarIconsOutline.altArrowDown,
                  color: MekaarColors.textPrimaryOf(context),
                  size: 22,
                ),
                if (newMessageCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MekaarColors.softCoral,
                        borderRadius: BorderRadius.circular(MekaarRadius.pill),
                      ),
                      child: Text(
                        newMessageCount > 99 ? '99+' : '$newMessageCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
