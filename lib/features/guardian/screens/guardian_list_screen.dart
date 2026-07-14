import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
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
    final myGuardians = ref.watch(guardianProvider);
    final whoAddedMe = ref.watch(whoAddedMeProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'Sistem Guardian',
          subtitle: 'Saling menjaga dalam situasi darurat',
        ),
        body: Column(
          children: [
            const TabBar(
              indicatorColor: MekaarColors.softCoral,
              labelColor: MekaarColors.textPrimary,
              unselectedLabelColor: MekaarColors.textMuted,
              tabs: [
                Tab(text: 'Guardian Saya'),
                Tab(text: 'Menjaga Siapa'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMyGuardiansTab(myGuardians),
                  _buildWhoAddedMeTab(whoAddedMe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGuardiansTab(List<Guardian> guardians) {
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
                border: Border.all(color: MekaarColors.border, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: MekaarColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'Tambah Guardian Baru',
                    style: TextStyle(color: MekaarColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: guardians.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada guardian terdaftar.\nTekan tombol di atas untuk menambah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MekaarColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: guardians.length,
                    itemBuilder: (context, index) {
                      final guardian = guardians[index];
                      return _buildGuardianCard(guardian, true);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoAddedMeTab(List<Guardian> list) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: list.isEmpty
          ? const Center(
              child: Text(
                'Belum ada yang menambahkan Anda sebagai Guardian.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MekaarColors.textMuted),
              ),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final guardian = list[index];
                return _buildGuardianCard(guardian, false);
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MekaarColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPending)
                        _buildBadge('Pending', MekaarColors.warning, MekaarColors.warningLight)
                      else if (isExpired)
                        _buildBadge('Expired', MekaarColors.sosRed, MekaarColors.sosLight)
                      else
                        _buildBadge('Aktif', MekaarColors.success, MekaarColors.successLight),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(guardian.email, style: const TextStyle(fontSize: 12, color: MekaarColors.textMuted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPermissionChip('GPS', guardian.permissions['gps'] ?? false),
                      const SizedBox(width: 6),
                      _buildPermissionChip('Audio', guardian.permissions['mic'] ?? false),
                      const Spacer(),
                      if (!isPending && !isExpired)
                        Text(
                          '${guardian.daysRemaining} hari lagi',
                          style: const TextStyle(fontSize: 10, color: MekaarColors.success, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isMyGuardian) ...[ 
              const Icon(Icons.chevron_right, color: MekaarColors.textMuted, size: 18),
            ] else if (isPending) ...[
              // Accept/Reject request
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: MekaarColors.success),
                    onPressed: () async {
                      await ref.read(whoAddedMeProvider.notifier).accept(guardian.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: MekaarColors.sosRed),
                    onPressed: () async {
                      await ref.read(whoAddedMeProvider.notifier).reject(guardian.id);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, color: textColor, fontWeight: FontWeight.w700),
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
            isEnabled ? Icons.check : Icons.close,
            size: 10,
            color: isEnabled ? MekaarColors.success : MekaarColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isEnabled ? MekaarColors.success : MekaarColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
