import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/repositories/chat_request_repository.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import 'private_vault_dialogs.dart';
import 'send_chat_invite_dialog.dart';

/// Bottom sheet terpusat untuk mencari dan menambahkan kontak baru
/// via `@username` atau email, lalu membuka ruang obrolan langsung.
class AddContactSheet {
  AddContactSheet._();

  /// Membuka bottom sheet tambah kontak.
  ///
  /// Jika [replaceRouteOnChat] bernilai `true` (misalnya dari layar penuh
  /// `NewChatScreen`), rute saat ini akan diganti saat obrolan dibuka.
  static void show(
    BuildContext context, {
    bool replaceRouteOnChat = false,
  }) {
    final parentNavigator = Navigator.of(context);
    MekaarBottomSheet.show<void>(
      context: context,
      title: 'Kontak Baru',
      showDragHandle: true,
      builder: (_) => _AddContactSheetContent(
        parentNavigator: parentNavigator,
        replaceRouteOnChat: replaceRouteOnChat,
      ),
    );
  }
}

class _AddContactSheetContent extends ConsumerStatefulWidget {
  final NavigatorState parentNavigator;
  final bool replaceRouteOnChat;

  const _AddContactSheetContent({
    required this.parentNavigator,
    required this.replaceRouteOnChat,
  });

  @override
  ConsumerState<_AddContactSheetContent> createState() =>
      _AddContactSheetContentState();
}

class _AddContactSheetContentState
    extends ConsumerState<_AddContactSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Input tidak boleh kosong');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final Map<String, dynamic>? profile;
      final isDuress = ref.read(authProvider).isDuressActive;

      if (isDuress) {
        await Future.delayed(const Duration(milliseconds: 600));
        profile = null;
      } else {
        profile = await ref.read(chatRepositoryProvider).searchProfile(query);
      }

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Pengguna tidak ditemukan';
        });
        return;
      }

      // Cegah existence oracle: di Mode Tamu/Duress, kontak vault terselubung
      // diperlakukan identik seperti akun tidak ditemukan.
      final targetUserId = profile['id'] as String;
      if (ref.read(authProvider).isDecoyActive &&
          VaultIsolationHelper.isContactCloaked(ref, targetUserId)) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Pengguna tidak ditemukan';
        });
        return;
      }

      final myId = ref.read(supabaseServiceProvider).currentUserId;
      if (profile['id'] == myId) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Tidak bisa memulai chat dengan diri sendiri';
        });
        return;
      }

      // Cegah memulai chat dengan pengguna yang diblokir
      final alreadyBlocked = await ref
          .read(blockRepositoryProvider)
          .isBlocked(profile['id'] as String);
      if (!mounted) return;
      if (alreadyBlocked) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Pengguna ini telah Anda blokir';
        });
        return;
      }

      // Cek proteksi undangan chat
      final chatReqRepo = ref.read(chatRequestRepositoryProvider);
      final isApproved = await chatReqRepo.isChatApproved(
        profile['id'] as String,
      );
      if (!mounted) return;

      if (!isApproved) {
        await SendChatInviteDialog.show(
          context,
          receiverId: profile['id'] as String,
          receiverUsername: profile['username'] as String? ?? 'User',
        );
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Proteksi Private Vault jika cloaked
      final isCloaked = VaultIsolationHelper.isContactCloaked(
        ref,
        targetUserId,
      );
      final targetSlot = VaultIsolationHelper.getContactVaultSlot(
        ref,
        targetUserId,
      );

      if (isCloaked) {
        final unlocked = await PrivateVaultDialogs.showUnlockPasscodeDialog(
          context,
          ref,
          targetSlot,
        );
        if (!unlocked || !mounted) return;
      }

      // Daftarkan kontak secara eksplisit & sinkronkan state kontak instan
      await ref
          .read(userContactsProvider.notifier)
          .addContact(profile['id'] as String);

      // Buat atau buka room chat
      final roomId = await ref
          .read(chatRoomsProvider.notifier)
          .getOrCreateRoom(
            profile['id'],
            'normal',
            screenshotEnabled: ref.read(screenshotBlockProvider),
          );

      if (!mounted) return;
      Navigator.pop(context);

      final rawName =
          (profile['display_name'] as String?)?.isNotEmpty == true
              ? profile['display_name'] as String
              : profile['full_name'] as String? ??
                  profile['username'] as String? ??
                  'User';
      final chatArgs = {
        'chatId': roomId,
        'chatName': rawName,
        'chatAvatar': rawName.isNotEmpty ? rawName[0] : 'U',
        'isGuardian': false,
        'otherUserId': profile['id'] as String?,
        'chatAvatarUrl': profile['avatar_url'] as String?,
      };

      if (!widget.parentNavigator.mounted) return;
      if (widget.replaceRouteOnChat) {
        widget.parentNavigator.pushReplacementNamed(
          AppRoutes.chat,
          arguments: chatArgs,
        );
      } else {
        widget.parentNavigator.pushNamed(
          AppRoutes.chat,
          arguments: chatArgs,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Gagal membuat chat: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan username atau email teman Anda untuk menambah kontak dan memulai obrolan langsung.',
          style: MekaarTypography.subtitle.copyWith(
            color: MekaarColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: MekaarSpacing.md),
        MekaarSearchField(
          controller: _searchController,
          hintText: 'Username atau Email',
          errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSearching ? null : _submitSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Cari & Chat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
