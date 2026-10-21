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
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_badge.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/guardian_provider.dart';
import '../../../data/models/guardian_model.dart';

class GuardianListScreen extends ConsumerStatefulWidget {
  const GuardianListScreen({super.key});

  @override
  ConsumerState<GuardianListScreen> createState() => _GuardianListScreenState();
}

class _GuardianListScreenState extends ConsumerState<GuardianListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_selectedTabIndex != _tabController.index) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    Future.microtask(() {
      ref.read(guardianProvider.notifier).refreshGuardians();
      ref.read(whoAddedMeProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;
    final myGuardians = wasDuress ? <Guardian>[] : ref.watch(guardianProvider);
    final whoAddedMe = wasDuress ? <Guardian>[] : ref.watch(whoAddedMeProvider);
    final myGuardiansStatus = ref.watch(guardianLoadStatusProvider);
    final whoAddedMeStatus = ref.watch(whoAddedMeLoadStatusProvider);
    final pendingCount = ref.watch(pendingIncomingGuardianCountProvider);

    return MekaarScaffold(
      flat: true,
      appBar: CustomAppBar(
        title: 'Sistem Guardian',
        subtitle: 'Saling menjaga dalam situasi darurat',
        actions: [
          if (myGuardians.isNotEmpty)
            IconButton(
              icon: const Icon(SolarIconsOutline.userPlus),
              tooltip: 'Tambah Guardian Baru',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.guardianAdd),
            ),
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
          const SizedBox(height: 6),
          MekaarSlidingSegmentBar(
            tabs: const ['Dijaga', 'Menjaga'],
            selectedIndex: _selectedTabIndex,
            badges: pendingCount > 0 ? {1: pendingCount} : null,
            onTabSelected: (index) {
              setState(() => _selectedTabIndex = index);
              _tabController.animateTo(index);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyGuardiansTab(myGuardians, myGuardiansStatus),
                _buildWhoAddedMeTab(whoAddedMe, whoAddedMeStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGuardiansTab(
    List<Guardian> guardians,
    GuardianLoadStatus status,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: status == GuardianLoadStatus.loading
          ? const MekaarStateView(
              pose: MikaPose.neutral,
              title: 'Memuat Guardian',
              message: 'Sedang mengambil daftar Guardian Anda...',
              layout: MekaarStateLayout.centered,
            )
          : status == GuardianLoadStatus.error
          ? _buildLoadError(
              () =>
                  ref.read(guardianProvider.notifier).refreshGuardians(),
            )
          : guardians.isEmpty
          ? AnimatedAppear(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MikaIllustration(
                        type: MikaIllustrationType.emptyGuardian,
                        size: 160,
                        semanticLabel: 'Belum ada guardian',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Guardian',
                        style: MekaarTypography.headingMD,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Tambahkan kontak tepercaya sebagai pelindung darurat Anda.',
                          style: MekaarTypography.bodyMD,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.guardianAdd),
                        icon: const Icon(SolarIconsBold.addCircle, size: 20),
                        label: Text(
                          'Tambah Guardian Baru',
                          style: MekaarTypography.labelLG.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: guardians.length,
              itemBuilder: (context, index) {
                final guardian = guardians[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedAppear(
                    delay: Duration(
                      milliseconds: (index * 40).clamp(0, 240),
                    ),
                    child: _buildGuardianCard(guardian, true),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildWhoAddedMeTab(List<Guardian> list, GuardianLoadStatus status) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: status == GuardianLoadStatus.loading
          ? const MekaarStateView(
              pose: MikaPose.neutral,
              title: 'Memuat Daftar',
              message: 'Sedang mengambil daftar yang menjaga Anda...',
              layout: MekaarStateLayout.centered,
            )
          : status == GuardianLoadStatus.error
          ? _buildLoadError(
              () => ref.read(whoAddedMeProvider.notifier).refresh(),
            )
          : list.isEmpty
          ? AnimatedAppear(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MikaIllustration(
                      type: MikaIllustrationType.emptyGuardian,
                      size: 160,
                      semanticLabel: 'Belum ada yang menambahkan Anda',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Yang Menjaga',
                      style: MekaarTypography.headingMD,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Belum ada kontak yang menambahkan Anda sebagai Guardian mereka.',
                        textAlign: TextAlign.center,
                        style: MekaarTypography.bodyMD.copyWith(
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final guardian = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedAppear(
                    delay: Duration(milliseconds: (index * 40).clamp(0, 240)),
                    child: _buildGuardianCard(guardian, false),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. Header: Avatar + Nama + Status Badge + Arrow ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Avatar(
                  initial: guardian.name.isNotEmpty ? guardian.name[0] : 'U',
                  size: 44,
                  isGuardian: guardian.status == 'active',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        guardian.name,
                        style: MekaarTypography.headingSM,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (guardian.email.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          guardian.email,
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textMutedOf(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isPending)
                  _buildBadge(
                    'Menunggu Persetujuan',
                    MekaarColors.warning,
                    MekaarColors.warningLight,
                  )
                else if (isExpired)
                  _buildBadge(
                    'Kadaluarsa',
                    MekaarColors.sosRed,
                    MekaarColors.sosLight,
                  )
                else
                  _buildBadge(
                    'Aktif',
                    MekaarColors.success,
                    MekaarColors.successLight,
                  ),
                if (isMyGuardian) ...[
                  const SizedBox(width: 6),
                  Icon(
                    SolarIconsOutline.altArrowRight,
                    color: MekaarColors.textMutedOf(context),
                    size: 16,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: MekaarColors.borderOf(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),

            // ── 2. Footer: Permissions & Remaining Time / Actions ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SolarIconsOutline.clockCircle,
                        size: 13,
                        color: guardian.daysRemaining <= 3
                            ? MekaarColors.warning
                            : MekaarColors.successTextOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${guardian.daysRemaining} hari lagi',
                        style: MekaarTypography.labelSM.copyWith(
                          color: guardian.daysRemaining <= 3
                              ? MekaarColors.warning
                              : MekaarColors.successTextOf(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (!isMyGuardian && isPending) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      SolarIconsOutline.checkCircle,
                      color: MekaarColors.success,
                      size: 22,
                    ),
                    tooltip: 'Terima undangan Guardian',
                    onPressed: () async {
                      try {
                        await ref
                            .read(whoAddedMeProvider.notifier)
                            .accept(guardian.id);
                      } catch (e) {
                        if (mounted) {
                          MekaarSnackbar.error(
                            context,
                            'Gagal menerima undangan: ${ErrorResolver.resolve(e)}',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      SolarIconsOutline.closeCircle,
                      color: MekaarColors.sosRed,
                      size: 22,
                    ),
                    tooltip: 'Tolak undangan Guardian',
                    onPressed: () => _confirmRejectGuardian(guardian),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
            final navigator = Navigator.of(context);
            try {
              await ref.read(whoAddedMeProvider.notifier).reject(guardian.id);
            } catch (e) {
              if (mounted) {
                MekaarSnackbar.error(context, 'Gagal menolak undangan.');
              }
            }
            navigator.pop();
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
      child: MekaarStateView(
        stateIcon: SolarIconsOutline.serverSquare,
        stateIconColor: MekaarColors.warnAmber,
        title: 'Gagal Memuat Guardian',
        message: 'Daftar Guardian tidak dapat dimuat. Silakan periksa jaringan Anda lalu coba lagi.',
        actionLabel: 'Coba Lagi',
        onAction: () => onRetry(),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return MekaarBadge(label: text, color: textColor);
  }

  Widget _buildPermissionChip(String label, bool isEnabled) {
    // Warna adaptif: chip pastel terang menyala di dark mode.
    final activeColor = MekaarColors.successTextOf(context);
    final inactiveColor = MekaarColors.textMutedOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled
            ? activeColor.withValues(alpha: 0.12)
            : MekaarColors.borderOf(context),
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
            color: isEnabled ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: MekaarTypography.labelSM.copyWith(
              color: isEnabled ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}