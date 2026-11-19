import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// Definisi satu aksi kontekstual pada [MekaarSelectionHeader].
class MekaarSelectionAction {
  final Key? key;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const MekaarSelectionAction({
    this.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
  });
}

/// Header aksi kontekstual terpusat untuk mode seleksi massal (multi-select)
/// di seluruh layar daftar MEKAAR (Pesan, Kontak, dll.).
///
/// Menggantikan [MekaarTabHeader] secara mulus saat mode seleksi aktif,
/// lengkap dengan tombol batal, penghitung jumlah terpilih, toggle Pilih Semua,
/// serta deretan aksi yang otomatis melimpah ke menu titik tiga bila melebihi
/// [maxVisibleInlineActions].
class MekaarSelectionHeader extends StatelessWidget {
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onToggleSelectAll;
  final List<MekaarSelectionAction> actions;
  final int maxVisibleInlineActions;

  const MekaarSelectionHeader({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onClose,
    required this.onToggleSelectAll,
    required this.actions,
    this.maxVisibleInlineActions = 3,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final primary = MekaarColors.primaryOf(context);
    final inlineActions = actions.take(maxVisibleInlineActions).toList();
    final overflowActions = actions.length > maxVisibleInlineActions
        ? actions.sublist(maxVisibleInlineActions)
        : const <MekaarSelectionAction>[];

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('mekaar_selection_close_btn'),
              icon: Icon(SolarIconsOutline.closeCircle, color: textPrimary),
              tooltip: 'Batalkan Pilihan',
              constraints: const BoxConstraints(
                minWidth: MekaarSizes.touchTargetMin,
                minHeight: MekaarSizes.touchTargetMin,
              ),
              onPressed: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                onClose();
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$selectedCount dipilih',
                key: const ValueKey('mekaar_selection_count_text'),
                style: MekaarTypography.headingMD.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const ValueKey('mekaar_selection_select_all_btn'),
              icon: Icon(
                allSelected
                    ? SolarIconsBold.checkSquare
                    : SolarIconsOutline.checkSquare,
                color: allSelected ? primary : textPrimary,
              ),
              tooltip: allSelected ? 'Batal Pilih Semua' : 'Pilih Semua',
              constraints: const BoxConstraints(
                minWidth: MekaarSizes.touchTargetMin,
                minHeight: MekaarSizes.touchTargetMin,
              ),
              onPressed: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                onToggleSelectAll();
              },
            ),
            for (final action in inlineActions)
              IconButton(
                key: action.key,
                icon: Icon(
                  action.icon,
                  color: action.onPressed == null
                      ? MekaarColors.textMutedOf(context)
                      : (action.isDestructive
                          ? MekaarColors.sosRed
                          : textPrimary),
                ),
                tooltip: action.tooltip,
                constraints: const BoxConstraints(
                  minWidth: MekaarSizes.touchTargetMin,
                  minHeight: MekaarSizes.touchTargetMin,
                ),
                onPressed: action.onPressed == null
                    ? null
                    : () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        action.onPressed!();
                      },
              ),
            if (overflowActions.isNotEmpty)
              PopupMenuButton<int>(
                key: const ValueKey('mekaar_selection_overflow_btn'),
                icon: Icon(SolarIconsOutline.menuDots, color: textPrimary),
                tooltip: 'Aksi Lainnya',
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.card),
                ),
                color: MekaarColors.surfaceOf(context),
                onSelected: (index) {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  overflowActions[index].onPressed?.call();
                },
                itemBuilder: (ctx) => [
                  for (var i = 0; i < overflowActions.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      enabled: overflowActions[i].onPressed != null,
                      child: Row(
                        children: [
                          Icon(
                            overflowActions[i].icon,
                            size: MekaarSizes.iconMd,
                            color: overflowActions[i].isDestructive
                                ? MekaarColors.sosRed
                                : textPrimary,
                          ),
                          const SizedBox(width: MekaarSpacing.md),
                          Expanded(
                            child: Text(
                              overflowActions[i].label,
                              style: MekaarTypography.bodyMD.copyWith(
                                color: overflowActions[i].isDestructive
                                    ? MekaarColors.sosRed
                                    : textPrimary,
                                fontWeight: overflowActions[i].isDestructive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
