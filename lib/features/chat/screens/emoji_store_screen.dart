import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/emoji_pack_model.dart';
import '../providers/emoji_pack_provider.dart';

/// Toko Emoji — browse pack katalog server, pasang ke composer,
/// atau hapus yang terpasang untuk hemat penyimpanan.
///
/// Pesan tetap hanya membawa `:slug:` terenkripsi; layar ini murni
/// mengelola aset lokal & tab panel composer.
class EmojiStoreScreen extends ConsumerWidget {
  const EmojiStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(emojiCatalogProvider);
    final installed = ref.watch(installedPacksProvider);

    return MekaarScaffold(
      flat: true,
      appBar: const CustomAppBar(
        title: 'Toko Emoji',
        subtitle: 'Pasang pack favoritmu, hapus bila tak dipakai',
      ),
      body: catalog.when(
        loading: () => const MekaarStateView(
          pose: _storeLoadingPose,
          title: 'Memuat Katalog',
          message: 'Mengambil daftar pack emoji...',
          layout: MekaarStateLayout.centered,
        ),
        error: (err, _) => MekaarStateView(
          pose: MikaPose.huft,
          title: 'Gagal Memuat Katalog',
          message: 'Periksa koneksi internet kamu lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          onAction: () =>
              ref.read(emojiCatalogProvider.notifier).reload(),
        ),
        data: (packs) {
          if (packs.isEmpty) {
            return const MekaarStateView(
              pose: MikaPose.ask,
              title: 'Belum Ada Pack',
              message: 'Katalog emoji masih kosong. Coba lagi nanti.',
              layout: MekaarStateLayout.centered,
            );
          }
          final installedPacks =
              packs.where((p) => installed.isInstalled(p.slug)).toList();
          final availablePacks =
              packs.where((p) => !installed.isInstalled(p.slug)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (installedPacks.isNotEmpty) ...[
                Text('TERPASANG', style: MekaarTypography.overline),
                const SizedBox(height: MekaarSpacing.sm),
                ...installedPacks.map((p) => _PackCard(
                      pack: p,
                      installed: true,
                      downloading: installed.isDownloading(p.slug),
                    )),
                const SizedBox(height: MekaarSpacing.lg),
              ],
              if (availablePacks.isNotEmpty) ...[
                Text('TERSEDIA', style: MekaarTypography.overline),
                const SizedBox(height: MekaarSpacing.sm),
                ...availablePacks.map((p) => _PackCard(
                      pack: p,
                      installed: false,
                      downloading: installed.isDownloading(p.slug),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// Pose generik untuk loading toko (ikon shield di StateView standar).
const _storeLoadingPose = MikaPose.pin;

class _PackCard extends ConsumerWidget {
  final EmojiPack pack;
  final bool installed;
  final bool downloading;

  const _PackCard({
    required this.pack,
    required this.installed,
    required this.downloading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: MekaarSpacing.md),
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
                child: pack.coverUrl != null
                    ? Image.network(
                        pack.coverUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 56,
                          height: 56,
                          color: MekaarColors.surface2Of(context),
                          child: Icon(
                            SolarIconsBold.stickerSmileCircle,
                            color: MekaarColors.textMutedOf(context),
                          ),
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: MekaarColors.surface2Of(context),
                        child: Icon(
                          SolarIconsBold.stickerSmileCircle,
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
              ),
              const SizedBox(width: MekaarSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: MekaarTypography.labelLG.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    if (pack.description != null &&
                        pack.description!.isNotEmpty)
                      Text(
                        pack.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${pack.itemCount} emoji · ${pack.formattedSize}',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MekaarSpacing.md),
          SizedBox(
            width: double.infinity,
            child: downloading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : OutlinedButton.icon(
                    onPressed: () => installed
                        ? _confirmUninstall(context, ref)
                        : _showDetailAndInstall(context, ref),
                    icon: Icon(
                      installed
                          ? SolarIconsOutline.trashBinMinimalistic
                          : SolarIconsOutline.downloadMinimalistic,
                      size: 18,
                      color: installed
                          ? MekaarColors.sosRed
                          : MekaarColors.accentTextOf(context),
                    ),
                    label: Text(
                      installed ? 'Hapus dari Perangkat' : 'Lihat & Tambahkan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: installed
                            ? MekaarColors.sosRed
                            : MekaarColors.accentTextOf(context),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: installed
                            ? MekaarColors.sosRed.withValues(alpha: 0.5)
                            : MekaarColors.accentTextOf(context)
                                .withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size.fromHeight(44),
                      shape: const StadiumBorder(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailAndInstall(
    BuildContext context,
    WidgetRef ref,
  ) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    await _openDetailSheet(context, ref, pack);
  }

  void _confirmUninstall(BuildContext context, WidgetRef ref) {
    HapticService.trigger(MekaarHapticIntent.warning);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: MekaarColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: Text('Hapus "${pack.name}"?', style: MekaarTypography.headingSM),
        content: Text(
          'File emoji (${pack.formattedSize}) akan dihapus dari perangkat '
          'untuk menghemat penyimpanan. Riwayat chat tidak terpengaruh — '
          'emoji tetap bisa dilihat lewat internet.',
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textSecondaryOf(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(installedPacksProvider.notifier).uninstall(pack.slug);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                MekaarSnackbar.info(
                  context,
                  'Pack "${pack.name}" dihapus dari perangkat.',
                );
              }
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: MekaarColors.sosRed),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet detail pack: preview seluruh item + tombol Tambahkan.
Future<void> _openDetailSheet(
  BuildContext context,
  WidgetRef ref,
  EmojiPack pack,
) async {
  final items = ref.read(emojiCatalogProvider.notifier).itemsOf(pack.slug);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Consumer(
      builder: (sheetCtx2, sheetRef, _) {
        final installed = sheetRef.watch(installedPacksProvider);
        final isInstalled = installed.isInstalled(pack.slug);
        final progress = installed.downloading[pack.slug];

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(MekaarSpacing.md),
            padding: const EdgeInsets.all(MekaarSpacing.lg),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(sheetCtx),
              borderRadius: BorderRadius.circular(MekaarRadius.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.name,
                            style: MekaarTypography.headingMD.copyWith(
                              color: MekaarColors.textPrimaryOf(sheetCtx),
                            ),
                          ),
                          Text(
                            '${pack.itemCount} emoji · ${pack.formattedSize}',
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(sheetCtx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MekaarSpacing.md),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 72,
                      mainAxisSpacing: MekaarSpacing.sm,
                      crossAxisSpacing: MekaarSpacing.sm,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Image.network(
                      items[i].fileUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: MekaarColors.surface2Of(sheetCtx),
                        child: Icon(
                          SolarIconsBold.stickerSmileCircle,
                          color: MekaarColors.textMutedOf(sheetCtx),
                          size: 20,
                        ),
                      ),
                      loadingBuilder: (_, child, loadProgress) =>
                          loadProgress == null
                              ? child
                              : ColoredBox(
                                  color: MekaarColors.surface2Of(sheetCtx),
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.lg),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MekaarSpacing.sm),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                    ),
                  ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: progress != null
                        ? null
                        : () async {
                            HapticService.trigger(
                                MekaarHapticIntent.success);
                            try {
                              await sheetRef
                                  .read(installedPacksProvider.notifier)
                                  .install(pack.slug);
                              if (sheetCtx.mounted) {
                                MekaarSnackbar.success(
                                  sheetCtx,
                                  '"${pack.name}" dipasang! Buka tab barunya di panel emoji.',
                                );
                                Navigator.pop(sheetCtx);
                              }
                            } catch (_) {
                              if (sheetCtx.mounted) {
                                MekaarSnackbar.error(
                                  sheetCtx,
                                  'Gagal mengunduh pack. Coba lagi.',
                                );
                              }
                            }
                          },
                    icon: Icon(
                      isInstalled
                          ? SolarIconsOutline.checkCircle
                          : SolarIconsOutline.downloadMinimalistic,
                      size: 20,
                    ),
                    label: Text(
                      isInstalled ? 'Terpasang' : 'Tambahkan ke Keyboard Emoji',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInstalled
                          ? MekaarColors.safeTextOf(sheetCtx)
                          : Theme.of(sheetCtx).colorScheme.primary,
                      foregroundColor: isInstalled
                          ? MekaarColors.textOnTeal
                          : MekaarColors.textOnBlue,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
