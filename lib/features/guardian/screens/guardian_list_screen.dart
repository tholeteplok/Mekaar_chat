import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/guardian_provider.dart';
import '../../../data/models/guardian_model.dart';

class GuardianListScreen extends ConsumerStatefulWidget {
  const GuardianListScreen({super.key});

  @override
  ConsumerState<GuardianListScreen> createState() => _GuardianListScreenState();
}

class _GuardianListScreenState extends ConsumerState<GuardianListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(guardianProvider.notifier).refreshGuardians();
      ref.read(whoAddedMeProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;
    final myGuardians = wasDuress ? <Guardian>[] : ref.watch(guardianProvider);
    final whoAddedMe = wasDuress ? <Guardian>[] : ref.watch(whoAddedMeProvider);
    final myGuardiansStatus = ref.watch(guardianLoadStatusProvider);
    final whoAddedMeStatus = ref.watch(whoAddedMeLoadStatusProvider);

    return DefaultTabController(
      length: 2,
      child: MekaarScaffold(
        appBar: CustomAppBar(
          title: 'Sistem Guardian',
          subtitle: 'Saling menjaga dalam situasi darurat',
          actions: [
            IconButton(
              icon: const Icon(SolarIconsOutline.gps),
              tooltip: 'Lacak Guardian',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.guardianTracking),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: MekaarColors.softCoral,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : MekaarColors.textSecondaryOf(context),
                labelStyle: MekaarTypography.labelMD.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: MekaarTypography.labelMD,
                tabs: const [
                  Tab(text: 'Guardian Saya'),
                  Tab(text: 'Menjaga Siapa'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMyGuardiansTab(myGuardians, myGuardiansStatus),
                  _buildWhoAddedMeTab(whoAddedMe, whoAddedMeStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGuardiansTab(
    List<Guardian> guardians,
    GuardianLoadStatus status,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Guardian Dotted Button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.guardianAdd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: MekaarColors.guardianTeal,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    SolarIconsOutline.addCircle,
                    color: MekaarColors.guardianTeal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tambah Guardian Baru',
                    style: MekaarTypography.labelLG.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.guardianTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: status == GuardianLoadStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : status == GuardianLoadStatus.error
                ? _buildLoadError(
                    () =>
                        ref.read(guardianProvider.notifier).refreshGuardians(),
                  )
                : guardians.isEmpty
                ? AnimatedAppear(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MikaIllustration(
                            pose: MikaPose.ask,
                            size: 110,
                            semanticLabel: 'Belum ada guardian',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada guardian terdaftar.',
                            style: MekaarTypography.headingSM,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tekan tombol di atas untuk menambah.',
                            style: MekaarTypography.bodyMD,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: guardians.length,
                    itemBuilder: (context, index) {
                      final guardian = guardians[index];
                      return AnimatedAppear(
                        delay: Duration(
                          milliseconds: (index * 40).clamp(0, 240),
                        ),
                        child: _buildGuardianCard(guardian, true),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoAddedMeTab(List<Guardian> list, GuardianLoadStatus status) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: status == GuardianLoadStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : status == GuardianLoadStatus.error
          ? _buildLoadError(
              () => ref.read(whoAddedMeProvider.notifier).refresh(),
            )
          : list.isEmpty
          ? AnimatedAppear(
              child: Center(
                child: Text(
                  'Belum ada yang menambahkan Anda sebagai Guardian.',
                  textAlign: TextAlign.center,
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textMuted,
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final guardian = list[index];
                return AnimatedAppear(
                  delay: Duration(milliseconds: (index * 40).clamp(0, 240)),
                  child: _buildGuardianCard(guardian, false),
                );
              },
            ),
    );
  }

  Widget _buildGuardianCard(Guardian guardian, bool isMyGuardian) {
    final isPending = guardian.status == 'pending';
    final isExpired = guardian.isExpired;

    return GestureDetector(
      onTap: isMyGuardian
          ? () => Navigator.pushNamed(
              context,
              AppRoutes.guardianDetail,
              arguments: {'guardian': guardian},
            )
          : null,
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Avatar(
              initial: guardian.name.isNotEmpty ? guardian.name[0] : 'U',
              size: 46,
              isGuardian: guardian.status == 'active',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guardian.name,
                          style: MekaarTypography.headingSM,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPending)
                        _buildBadge(
                          'Pending',
                          MekaarColors.warning,
                          MekaarColors.warningLight,
                        )
                      else if (isExpired)
                        _buildBadge(
                          'Expired',
                          MekaarColors.sosRed,
                          MekaarColors.sosLight,
                        )
                      else
                        _buildBadge(
                          'Aktif',
                          MekaarColors.success,
                          MekaarColors.successLight,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(guardian.email, style: MekaarTypography.bodySM),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPermissionChip(
                        'GPS',
                        guardian.permissions['gps'] ?? false,
                      ),
                      const SizedBox(width: 6),
                      _buildPermissionChip(
                        'Audio',
                        guardian.permissions['mic'] ?? false,
                      ),
                      const Spacer(),
                      if (!isPending && !isExpired)
                        Text(
                          '${guardian.daysRemaining} hari lagi',
                          style: MekaarTypography.labelSM.copyWith(
                            color: MekaarColors.success,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isMyGuardian) ...[
              IconButton(
                icon: const Icon(
                  SolarIconsOutline.linkBroken,
                  color: MekaarColors.sosRed,
                ),
                tooltip: 'Putus Paksa Guardian',
                onPressed: (!isPending && !isExpired)
                    ? () => _confirmBreakGuardian(guardian)
                    : null,
              ),
              const Icon(
                SolarIconsOutline.altArrowRight,
                color: MekaarColors.textMuted,
                size: 18,
              ),
            ] else if (isPending) ...[
              // Accept/Reject request
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      SolarIconsOutline.checkCircle,
                      color: MekaarColors.success,
                    ),
                    tooltip: 'Terima undangan Guardian',
                    onPressed: () async {
                      await ref
                          .read(whoAddedMeProvider.notifier)
                          .accept(guardian.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      SolarIconsOutline.closeCircle,
                      color: MekaarColors.sosRed,
                    ),
                    tooltip: 'Tolak undangan Guardian',
                    onPressed: () => _confirmRejectGuardian(guardian),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmBreakGuardian(Guardian guardian) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Putus Paksa Guardian?',
      message:
          'Hubungan dengan ${guardian.name} akan diputus secara instan dan ia diblokir mengirim undangan selama 24 jam.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref
                .read(guardianProvider.notifier)
                .breakGuardian(guardian.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Hubungan dengan ${guardian.name} diputus. Blokir 24 jam aktif.',
                  ),
                ),
              );
            }
          },
          child: const Text(
            'Putus Paksa',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _confirmRejectGuardian(Guardian guardian) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Tolak undangan Guardian?',
      message:
          'Undangan dari ${guardian.name} akan dihapus dan tidak dapat dipulihkan.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(whoAddedMeProvider.notifier).reject(guardian.id);
          },
          child: const Text(
            'Tolak',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError(Future<void> Function() onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SolarIconsOutline.dangerTriangle,
            size: 36,
            color: MekaarColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Daftar Guardian tidak dapat dimuat.',
            textAlign: TextAlign.center,
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: MekaarTypography.labelSM.copyWith(color: textColor, fontSize: 9),
      ),
    );
  }

  Widget _buildPermissionChip(String label, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled ? MekaarColors.successLight : MekaarColors.borderLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled
                ? SolarIconsOutline.checkCircle
                : SolarIconsOutline.closeCircle,
            size: 10,
            color: isEnabled ? MekaarColors.success : MekaarColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: MekaarTypography.labelSM.copyWith(
              fontSize: 9,
              color: isEnabled ? MekaarColors.success : MekaarColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
