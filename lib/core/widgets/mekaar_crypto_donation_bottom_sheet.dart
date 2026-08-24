import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'animations.dart';
import 'mekaar_bottom_sheet.dart';
import 'mekaar_snackbar.dart';

/// Model item donasi kripto.
class CryptoWalletItem {
  final String coinName;
  final String networkLabel;
  final String address;
  final IconData icon;
  final Color brandColor;

  const CryptoWalletItem({
    required this.coinName,
    required this.networkLabel,
    required this.address,
    required this.icon,
    required this.brandColor,
  });
}

/// MekaarCryptoDonationBottomSheet — Bottom sheet terpusat untuk donasi pengembang.
class MekaarCryptoDonationBottomSheet extends StatelessWidget {
  const MekaarCryptoDonationBottomSheet({super.key});

  static const List<CryptoWalletItem> _wallets = [
    CryptoWalletItem(
      coinName: 'Solana (SOL)',
      networkLabel: 'Solana Native (SOL & SPL)',
      address: '8NygxsjfWmcDMMTVuBS2VSAq7b6MnfGTqsPutCfLobyk',
      icon: SolarIconsBold.tuningSquare,
      brandColor: Color(0xFF14F195),
    ),
    CryptoWalletItem(
      coinName: 'EVM Multi-Chain (ETH)',
      networkLabel: 'Ethereum, Base, Arbitrum, Polygon, BNB',
      address: '0x49a2013dcbb322079e18136e25e39ab940a74c5e',
      icon: SolarIconsBold.layersMinimalistic,
      brandColor: Color(0xFF627EEA),
    ),
    CryptoWalletItem(
      coinName: 'TRON (TRX / USDT)',
      networkLabel: 'TRON Network (TRX & USDT-TRC20)',
      address: 'TBQf6zEfjhsBbcAAyam626JED3ordfX6Y1',
      icon: SolarIconsBold.shieldKeyhole,
      brandColor: Color(0xFFFF060A),
    ),
    CryptoWalletItem(
      coinName: 'Bitcoin (BTC)',
      networkLabel: 'Bitcoin Network Native',
      address: 'bc1pywldcavnzq7ztmsqvm8unq3rkrlzafvenzhgmsvz7t32ysq0lcvqmcwfvw',
      icon: SolarIconsBold.wallet2,
      brandColor: Color(0xFFF7931A),
    ),
  ];

  /// Menampilkan Bottom Sheet Donasi Crypto
  static Future<void> show(BuildContext context) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const MekaarCryptoDonationBottomSheet(),
    );
  }

  void _copyToClipboard(BuildContext context, CryptoWalletItem wallet) {
    Clipboard.setData(ClipboardData(text: wallet.address));
    HapticService.trigger(MekaarHapticIntent.success);
    MekaarSnackbar.success(
      context,
      'Alamat ${wallet.coinName} berhasil disalin ke papan klip.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.blue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Ikon & Judul ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                SolarIconsBold.heart,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dukung MEKAAR 💙',
                    style: MekaarTypography.headingSM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kontribusi sukarela untuk pengembangan berkelanjutan',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Text(
          'MEKAAR dibangun tanpa iklan & tanpa komersialisasi data. Kontribusi sukarela Anda membantu pemeliharaan server relay, infrastruktur WebRTC, dan riset privasi.',
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textSecondaryOf(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // ── Daftar Kartu Wallet ──
        for (int i = 0; i < _wallets.length; i++) ...[
          _buildWalletCard(context, _wallets[i], isDark),
          if (i < _wallets.length - 1) const SizedBox(height: 10),
        ],

        const SizedBox(height: 16),

        // ── Catatan Keamanan Jaringan ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E304F).withValues(alpha: 0.6)
                : const Color(0xFFF1F6FB),
            borderRadius: BorderRadius.circular(MekaarRadius.md),
            border: Border.all(
              color: isDark ? const Color(0xFF25395B) : const Color(0xFFDCE7F5),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                SolarIconsOutline.infoCircle,
                size: 18,
                color: AppColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pastikan aset digital dikirim melalui jaringan yang sesuai agar transaksi valid.',
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildWalletCard(
    BuildContext context,
    CryptoWalletItem wallet,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A44) : Colors.white,
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: isDark ? const Color(0xFF25395B) : const Color(0xFFDCE7F5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: wallet.brandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  wallet.icon,
                  size: 16,
                  color: wallet.brandColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.coinName,
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      wallet.networkLabel,
                      style: MekaarTypography.caption.copyWith(
                        fontSize: 11,
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              PressableScale(
                onTap: () => _copyToClipboard(context, wallet),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SolarIconsOutline.copy,
                        size: 14,
                        color: AppColors.blue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Salin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131F33) : const Color(0xFFF6F9FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              wallet.address,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: MekaarColors.textPrimaryOf(context),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
