import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_section_header.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';
import '../widgets/add_contact_sheet.dart';
import '../widgets/private_vault_dialogs.dart';

/// Layar penuh "Pesan Baru" (standar WhatsApp/Telegram).
/// Menyediakan navigasi cepat untuk Grup Baru, Kontak Baru (via search / QR),
/// dan daftar kontak milik sendiri dengan pemisahan isolasi Mode Master vs Mode Guest.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChatWithContact(ContactItem contact) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      final isCloaked = VaultIsolationHelper.isContactCloaked(
        ref,
        contact.contactUserId,
        knownSlot: contact.vaultSlot,
      );

      if (isCloaked) {
        final unlocked = await PrivateVaultDialogs.showUnlockPasscodeDialog(
          context,
          ref,
          contact.vaultSlot,
        );
        if (!unlocked || !mounted) {
          setState(() => _isActionInProgress = false);
          return;
        }
      }

      final roomId = await ref.read(chatRoomsProvider.notifier).getOrCreateRoom(
            contact.contactUserId,
            contact.isGuardian ? 'guardian' : 'normal',
            screenshotEnabled: ref.read(screenshotBlockProvider),
          );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'chatId': roomId,
          'chatName': contact.effectiveName,
          'chatAvatar': contact.effectiveName.isNotEmpty
              ? contact.effectiveName[0].toUpperCase()
              : '?',
          'chatAvatarUrl': contact.avatarUrl,
          'isGuardian': contact.isGuardian,
          'otherUserId': contact.contactUserId,
        },
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal membuka obrolan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.trigger(MekaarHapticIntent.selection);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: MekaarSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuestActive || authState.isDuressActive;
    final contactsAsync = ref.watch(userContactsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);

    final availableContacts = contactsAsync.maybeWhen(
      data: (items) {
        final list = items.where((c) {
          if (isGuest) {
            if (c.isVaulted) return false;
            if (hiddenContactUserIds.contains(c.contactUserId)) return false;
          }
          return true;
        }).toList();
        list.sort(
          (a, b) => a.effectiveName.toLowerCase().compareTo(b.effectiveName.toLowerCase()),
        );
        return list;
      },
      orElse: () => <ContactItem>[],
    );

    final filteredContacts = availableContacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      final name = c.effectiveName.toLowerCase();
      final username = c.username.toLowerCase();
      final email = (c.email ?? '').toLowerCase();
      return name.contains(q) || username.contains(q) || email.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: MekaarTopBar(
        title: 'Pesan Baru',
        subtitle: contactsAsync.maybeWhen(
          data: (_) => '${availableContacts.length} kontak',
          orElse: () => null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aksi Cepat 1: Grup Baru
          _buildQuickActionItem(
            icon: SolarIconsOutline.usersGroupTwoRounded,
            iconColor: AppColors.blue,
            iconBgColor: AppColors.blue.withValues(alpha: 0.12),
            title: 'Grup Baru',
            subtitle: 'Obrolan bersama beberapa anggota',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.createGroupSelectMembers),
          ),

          // Aksi Cepat 2: Kontak Baru & QR Scanner Shortcut
          _buildQuickActionItem(
            icon: SolarIconsOutline.userPlus,
            iconColor: AppColors.safeTeal,
            iconBgColor: AppColors.safeTeal.withValues(alpha: 0.15),
            title: 'Kontak Baru',
            subtitle: 'Tambah teman via username atau email',
            trailing: Container(
              decoration: BoxDecoration(
                color: MekaarColors.surface2Of(context),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(SolarIconsOutline.qrCode, size: 20),
                color: AppColors.blue,
                tooltip: 'Pindai Kode QR',
                onPressed: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  Navigator.pushNamed(context, AppRoutes.contactQrScan);
                },
              ),
            ),
            onTap: () => AddContactSheet.show(context, replaceRouteOnChat: true),
          ),

          // Bilah Pencarian Kontak Saya
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.md,
              vertical: MekaarSpacing.sm,
            ),
            child: MekaarSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Cari kontak Anda...',
              onChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer = Timer(const Duration(milliseconds: 120), () {
                  if (mounted && _searchQuery != val.trim().toLowerCase()) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  }
                });
              },
            ),
          ),

          // Header Seksi: Kontak Saya
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.md),
            child: MekaarSectionHeader(
              title: 'Kontak Saya',
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
            ),
          ),

          // Daftar Kontak Saya
          Expanded(
            child: contactsAsync.when(
              loading: () => const MekaarStateView(
                pose: MikaPose.neutral,
                title: 'Memuat Kontak',
                message: 'Mengambil daftar kontak Anda...',
                semanticLabel: 'Memuat daftar kontak',
              ),
              error: (err, stack) => MekaarStateView(
                pose: MikaPose.thinking,
                title: 'Gagal Memuat Kontak',
                message: 'Terjadi kesalahan saat memuat kontak Anda.',
                actionLabel: 'Coba Lagi',
                onAction: () => ref
                    .read(userContactsProvider.notifier)
                    .refreshContacts(forceLoading: true),
              ),
              data: (_) {
                if (availableContacts.isEmpty) {
                  return MekaarStateView(
                    pose: MikaPose.neutral,
                    title: isGuest ? 'Tidak Ada Kontak Terbuka' : 'Belum Ada Kontak',
                    message: isGuest
                        ? 'Tidak ada kontak non-rahasia yang dapat ditampilkan pada Mode Tamu.'
                        : 'Tambah kontak baru melalui username/email atau pindai kode QR.',
                  );
                }

                if (filteredContacts.isEmpty) {
                  return MekaarStateView(
                    pose: MikaPose.thinking,
                    title: 'Tidak Ditemukan',
                    message: 'Tidak ada kontak yang cocok dengan "$_searchQuery".',
                  );
                }

                return ListView.separated(
                  itemCount: filteredContacts.length,
                  separatorBuilder: (ctx, idx) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    color: MekaarColors.borderOf(context).withValues(alpha: 0.15),
                  ),
                  itemBuilder: (ctx, idx) {
                    final contact = filteredContacts[idx];
                    final name = contact.effectiveName;
                    final username = contact.username;
                    final email = contact.email ?? '';
                    final isGuardian = contact.isGuardian;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openChatWithContact(contact),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MekaarSpacing.md,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Avatar(
                                size: 44,
                                imageUrl: contact.avatarUrl,
                                initial: name.isNotEmpty ? name[0] : 'K',
                              ),
                              const SizedBox(width: MekaarSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: MekaarTypography.bodyMD.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: MekaarColors.textPrimaryOf(context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (contact.isVaulted && !isGuest) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MekaarColors.accentOf(context)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  SolarIconsOutline.lockKeyhole,
                                                  size: 11,
                                                  color: MekaarColors.accentOf(context),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Vault',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        MekaarColors.accentOf(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (isGuardian) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MekaarColors.safeTextOf(context)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Guardian',
                                              style: MekaarTypography.caption.copyWith(
                                                color: MekaarColors.safeTextOf(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      username.isNotEmpty ? '@$username' : email,
                                      style: MekaarTypography.bodySM.copyWith(
                                        color: MekaarColors.textSecondaryOf(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
