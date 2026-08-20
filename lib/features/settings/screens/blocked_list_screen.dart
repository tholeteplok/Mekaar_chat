import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/avatar.dart';
import '../providers/block_provider.dart';
import '../widgets/settings_tiles.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../auth/providers/auth_provider.dart';

class BlockedListScreen extends ConsumerWidget {
  const BlockedListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedState = ref.watch(blockProvider);
    final supabaseService = ref.watch(supabaseServiceProvider);
    final repo = ChatRepository(supabaseService);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Daftar Blokir'),
            Expanded(
              child: blockedState.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MikaIllustration(
                            pose: MikaPose.hide,
                            size: 110,
                            semanticLabel: 'Tidak ada pengguna diblokir',
                          ),
                          const SizedBox(height: MekaarSpacing.lg),
                          Text(
                            'Tidak ada pengguna diblokir',
                            style: MekaarTypography.headingMD.copyWith(
                              color: MekaarColors.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: MekaarSpacing.sm),
                          Padding(
                            padding: MekaarSpacing.screen,
                            child: Text(
                              'Pengguna yang Anda blokir tidak bisa mengirim pesan atau menjadikan Anda guardian.',
                              textAlign: TextAlign.center,
                              style: MekaarTypography.bodyMD.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final blocked = list[index];
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: repo.searchProfileById(blocked.blockedId),
                        builder: (context, snapshot) {
                          final profile = snapshot.data;
                          final name = profile?['full_name'] as String? ??
                              profile?['username'] as String? ??
                              'Pengguna';
                          return CustomCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Avatar(
                                initial: name,
                                imageUrl: profile?['avatar_url'] as String?,
                                size: 42,
                              ),
                              title: Text(
                                name,
                                style: MekaarTypography.labelLG.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: MekaarColors.textPrimaryOf(context),
                                ),
                              ),
                              subtitle: Text(
                                'Diblokir',
                                style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.sosRed,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: MekaarColors.cyan,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(blockProvider.notifier)
                                      .unblockUser(blocked.blockedId);
                                  if (context.mounted) {
                                    MekaarSnackbar.success(
                                      context,
                                      'Pengguna dibuka blokirnya.',
                                    );
                                  }
                                },
                                child: const Text(
                                  'Buka Blokir',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const MekaarStateView(
                  pose: MikaPose.hide,
                  title: 'Memuat Daftar Blokir',
                  message: 'Sedang mengambil daftar pengguna yang Anda blokir...',
                ),
                error: (err, _) => MekaarStateView(
                  pose: MikaPose.huft,
                  title: 'Gagal Memuat Daftar Blokir',
                  message: ErrorResolver.resolve(err),
                  actionLabel: 'Coba Lagi',
                  onAction: () => ref.invalidate(blockProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
