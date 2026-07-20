import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/avatar.dart';
import '../providers/block_provider.dart';
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
      appBar: const CustomAppBar(title: 'Daftar Blokir'),
      body: blockedState.when(
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
                  Text('Tidak ada pengguna diblokir',
                      style: MekaarTypography.headingMD),
                  const SizedBox(height: MekaarSpacing.sm),
                  Padding(
                    padding: MekaarSpacing.screen,
                    child: Text(
                      'Pengguna yang Anda blokir tidak bisa mengirim pesan atau menjadikan Anda guardian.',
                      textAlign: TextAlign.center,
                      style: MekaarTypography.bodyMD,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (context, index) =>
                const Divider(color: MekaarColors.borderLight),
            itemBuilder: (context, index) {
              final blocked = list[index];
              return FutureBuilder<Map<String, dynamic>?>(
                future: repo.searchProfileById(blocked.blockedId),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final name = profile?['full_name'] as String? ??
                      profile?['username'] as String? ??
                      'Pengguna';
                  return ListTile(
                    leading: Avatar(
                      initial: name,
                      imageUrl: profile?['avatar_url'] as String?,
                      size: 40,
                    ),
                    title: Text(name, style: MekaarTypography.labelLG),
                    subtitle: Text(
                      'Diblokir',
                      style: MekaarTypography.bodySM
                          .copyWith(color: MekaarColors.textMuted),
                    ),
                    trailing: TextButton(
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
                      child: const Text('Buka Blokir'),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Gagal memuat: $err', style: MekaarTypography.bodyMD),
        ),
      ),
    );
  }
}
