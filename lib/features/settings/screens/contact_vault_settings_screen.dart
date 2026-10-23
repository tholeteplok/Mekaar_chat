import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../chat/providers/private_vault_provider.dart';
import '../../chat/widgets/private_vault_dialogs.dart';
import '../widgets/settings_tiles.dart';

/// Layar Pengaturan Kontak Vault Multi-Slot & Privasi Lanjutan
class ContactVaultSettingsScreen extends ConsumerStatefulWidget {
  const ContactVaultSettingsScreen({super.key});

  @override
  ConsumerState<ContactVaultSettingsScreen> createState() =>
      _ContactVaultSettingsScreenState();
}

class _ContactVaultSettingsScreenState
    extends ConsumerState<ContactVaultSettingsScreen> {
  bool _isLoading = true;
  List<int> _activeSlots = [1];
  final Map<int, String> _slotNames = {1: 'Profil 1', 2: 'Profil 2', 3: 'Profil 3'};
  final Map<int, bool> _hasPasscodes = {1: false, 2: false, 3: false};

  @override
  void initState() {
    super.initState();
    _loadSlotsData();
  }

  Future<void> _loadSlotsData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(privateContactRepositoryProvider);

    final active = await repo.getActiveSlots();
    for (int slot = 1; slot <= 3; slot++) {
      _slotNames[slot] = await repo.getSlotName(slot);
      _hasPasscodes[slot] = await repo.hasSlotPasscode(slot);
    }

    if (mounted) {
      setState(() {
        _activeSlots = active;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRenameSlot(int slot) async {
    final controller = TextEditingController(text: _slotNames[slot]);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => MekaarDialog(
        icon: const Icon(SolarIconsOutline.pen, color: AppColors.blue, size: 24),
        title: 'Ubah Nama Profil Slot $slot',
        message: 'Beri nama yang memudahkan Anda mengidentifikasi kompartemen ini.',
        customContent: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Mis. Bisnis, Lingkaran Rahasia',
            filled: true,
            fillColor: MekaarColors.surface2Of(ctx),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MekaarRadius.md),
              borderSide: BorderSide(color: MekaarColors.borderOf(ctx)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      final repo = ref.read(privateContactRepositoryProvider);
      await repo.setSlotName(slot, newName);
      if (!mounted) return;
      setState(() => _slotNames[slot] = newName);
      MekaarSnackbar.success(context, 'Nama profil berhasil diperbarui');
    }
  }

  Future<void> _handleAddNewSlot() async {
    if (_activeSlots.length >= 3) {
      MekaarSnackbar.info(context, 'Maksimal 3 profil slot vault yang dapat dibuat.');
      return;
    }

    int nextSlot = 1;
    for (int s = 1; s <= 3; s++) {
      if (!_activeSlots.contains(s)) {
        nextSlot = s;
        break;
      }
    }

    final success = await PrivateVaultDialogs.showSetPasscodeDialog(
      context,
      ref,
      slot: nextSlot,
      slotName: _slotNames[nextSlot] ?? 'Profil $nextSlot',
    );

    if (success && mounted) {
      HapticService.trigger(MekaarHapticIntent.success);
      await _loadSlotsData();
      if (!mounted) return;
      MekaarSnackbar.success(
        context,
        '${_slotNames[nextSlot]} berhasil dibuat dan siap digunakan.',
      );
    }
  }

  Future<void> _handleDeleteSlot(int slot) async {
    if (slot == 1) {
      MekaarSnackbar.error(context, 'Slot 1 adalah profil utama dan tidak dapat dihapus.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        icon: const Icon(SolarIconsOutline.trashBinTrash, color: MekaarColors.sosRed, size: 28),
        title: 'Hapus ${_slotNames[slot]}?',
        message:
            'Menghapus profil ini akan otomatis MENGELUARKAN seluruh kontak di dalamnya dari vault ke kontak biasa, dan menghapus kode akses slot ini.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Profil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      // 1. Ambil seluruh kontak yang berada di slot yang akan dihapus
      final contactsInSlot = ref
              .read(userContactsProvider)
              .value
              ?.where((c) => c.vaultSlot == slot && c.isVaulted)
              .toList() ??
          [];

      // 2. Bersihkan contactUserId dari set lokal hiddenContactUserIds
      final hiddenNotifier = ref.read(hiddenContactUserIdsProvider.notifier);
      for (final c in contactsInSlot) {
        await hiddenNotifier.removeContact(c.contactUserId);
      }

      // 3. Cabut slot dari unlockedVaultSlotsProvider di RAM
      ref
          .read(unlockedVaultSlotsProvider.notifier)
          .update((s) => s.where((x) => x != slot).toSet());
      if (ref.read(unlockedVaultSlotsProvider).isEmpty) {
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }

      // 4. Hapus passcode slot di Secure Storage
      final repo = ref.read(privateContactRepositoryProvider);
      await repo.deleteSlotPasscode(slot);

      // 5. Panggil RPC Supabase untuk mengeluarkan kontak dari slot tersebut
      await ref.read(contactRepositoryProvider).deleteVaultSlot(slot);
      ref.invalidate(userContactsProvider);

      await _loadSlotsData();
      if (mounted) {
        MekaarSnackbar.info(
          context,
          'Profil slot $slot telah dihapus dan seluruh kontak di dalamnya telah dikembalikan.',
        );
      }
    }
  }

  Future<void> _handleResetPasscodeViaPin(int slot) async {
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Utama',
      subtitle: 'Masukkan 6 digit PIN aplikasi untuk mereset kode akses ${_slotNames[slot]}',
    );

    if (!verified || !mounted) return;

    final success = await PrivateVaultDialogs.showSetPasscodeDialog(
      context,
      ref,
      slot: slot,
      slotName: _slotNames[slot],
      isResetFlow: true,
    );

    if (success && mounted) {
      HapticService.trigger(MekaarHapticIntent.success);
      await _loadSlotsData();
      if (!mounted) return;
      MekaarSnackbar.success(
        context,
        'Kode akses baru untuk ${_slotNames[slot]} berhasil disimpan.',
      );
    }
  }

  Future<void> _handleChangePasscode(int slot) async {
    final success = await PrivateVaultDialogs.showChangePasscodeDialog(
      context,
      ref,
      slot: slot,
      slotName: _slotNames[slot],
    );

    if (success && mounted) {
      HapticService.trigger(MekaarHapticIntent.success);
      await _loadSlotsData();
    }
  }

  Future<void> _moveContactToSlot(ContactItem contact, int targetSlot) async {
    if (contact.vaultSlot == targetSlot) return;

    Navigator.pop(context); // Tutup action sheet
    HapticService.trigger(MekaarHapticIntent.selection);

    await ref.read(contactRepositoryProvider).updateContactVaultStatus(
          contact.contactUserId,
          true,
          vaultSlot: targetSlot,
        );
    ref.invalidate(userContactsProvider);

    if (mounted) {
      MekaarSnackbar.success(
        context,
        '${contact.effectiveName} dipindahkan ke ${_slotNames[targetSlot]}',
      );
    }
  }

  Future<void> _unvaultContact(ContactItem contact) async {
    Navigator.pop(context); // Tutup action sheet
    HapticService.trigger(MekaarHapticIntent.selection);

    await ref.read(contactRepositoryProvider).updateContactVaultStatus(
          contact.contactUserId,
          false,
          vaultSlot: 1,
        );
    ref.read(hiddenContactUserIdsProvider.notifier).removeContact(contact.contactUserId);
    ref.invalidate(userContactsProvider);

    if (mounted) {
      MekaarSnackbar.info(
        context,
        '${contact.effectiveName} telah dikeluarkan dari Private Vault',
      );
    }
  }

  void _showContactActionsSheet(ContactItem contact) {
    HapticService.trigger(MekaarHapticIntent.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: MekaarColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Avatar(
                        initial: contact.effectiveName[0],
                        imageUrl: contact.avatarUrl,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.effectiveName,
                              style: MekaarTypography.headingSM.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Saat ini di ${_slotNames[contact.vaultSlot]}',
                              style: MekaarTypography.caption.copyWith(
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final targetSlot in _activeSlots)
                  if (targetSlot != contact.vaultSlot)
                    ListTile(
                      leading: Icon(
                        SolarIconsOutline.transferHorizontal,
                        color: MekaarColors.primaryOf(context),
                      ),
                      title: Text('Pindahkan ke ${_slotNames[targetSlot]}'),
                      onTap: () => _moveContactToSlot(contact, targetSlot),
                    ),
                ListTile(
                  leading: const Icon(
                    SolarIconsOutline.eye,
                    color: MekaarColors.guardianTeal,
                  ),
                  title: const Text('Keluarkan dari Vault (Jadikan Publik)'),
                  onTap: () => _unvaultContact(contact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(userContactsProvider);
    final allContacts = contactsAsync.value ?? <ContactItem>[];

    Color getSlotColor(int slot) {
      switch (slot) {
        case 1:
          return MekaarColors.guardianTeal;
        case 2:
          return MekaarColors.warnAmber;
        case 3:
          return MekaarColors.purpleLight;
        default:
          return MekaarColors.primaryOf(context);
      }
    }

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopBar(
              title: 'Manajemen Vault',
              subtitle: 'Kelola hingga 3 slot profil vault terisolasi',
              trailing: _activeSlots.length < 3
                  ? IconButton(
                      icon: const Icon(
                        SolarIconsOutline.addCircle,
                        color: MekaarColors.cyan,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: MekaarColors.surface2Of(context)
                            .withValues(alpha: 0.85),
                        side: BorderSide(
                          color: MekaarColors.cardBorderOf(context)
                              .withValues(alpha: 0.8),
                          width: 1.0,
                        ),
                        shape: const CircleBorder(),
                      ),
                      tooltip: 'Tambah Profil Slot',
                      onPressed: _handleAddNewSlot,
                    )
                  : null,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Banner Penjelasan
                CustomCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        SolarIconsBold.shieldKeyhole,
                        color: MekaarColors.guardianTeal,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Kelola hingga 3 profil slot vault terisolasi. Tiap slot memiliki kode akses unik. Masukkan kode akses di bilah pencarian kontak untuk membuka profil tersebut. Lupa kode dapat direset menggunakan PIN Utama.',
                          style: MekaarTypography.bodySM.copyWith(
                            color: MekaarColors.textSecondaryOf(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Daftar Slot Vault
                for (final slot in _activeSlots) ...[
                  Builder(builder: (ctx) {
                    final slotContacts = allContacts
                        .where((c) => c.isVaulted && c.vaultSlot == slot)
                        .toList();
                    final slotColor = getSlotColor(slot);
                    final isSlot1 = slot == 1;

                    return CustomCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Slot
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: slotColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  SolarIconsBold.shieldKeyhole,
                                  color: slotColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _slotNames[slot] ?? 'Profil $slot',
                                        style: MekaarTypography.headingSM.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(SolarIconsOutline.pen, size: 16),
                                      color: MekaarColors.textMutedOf(context),
                                      tooltip: 'Ubah Nama Profil',
                                      onPressed: () => _handleRenameSlot(slot),
                                    ),
                                    if (isSlot1) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MekaarColors.guardianTeal.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Default',
                                          style: MekaarTypography.caption.copyWith(
                                            color: MekaarColors.guardianTeal,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isSlot1)
                                IconButton(
                                  icon: const Icon(SolarIconsOutline.trashBinTrash, size: 20),
                                  color: MekaarColors.sosCoral,
                                  tooltip: 'Hapus Profil Ini',
                                  onPressed: () => _handleDeleteSlot(slot),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Status Kode & Tombol Aksi Kode
                          Row(
                            children: [
                              Icon(
                                _hasPasscodes[slot] == true
                                    ? SolarIconsBold.lock
                                    : SolarIconsOutline.lockUnlocked,
                                size: 14,
                                color: _hasPasscodes[slot] == true
                                    ? MekaarColors.successTextOf(context)
                                    : MekaarColors.warnAmber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _hasPasscodes[slot] == true
                                    ? 'Kode Akses Aktif'
                                    : 'Belum Ada Kode Akses',
                                style: MekaarTypography.caption.copyWith(
                                  color: _hasPasscodes[slot] == true
                                      ? MekaarColors.successTextOf(context)
                                      : MekaarColors.warnAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                onPressed: () {
                                  if (_hasPasscodes[slot] == true) {
                                    _handleChangePasscode(slot);
                                  } else {
                                    PrivateVaultDialogs.showSetPasscodeDialog(
                                      context,
                                      ref,
                                      slot: slot,
                                      slotName: _slotNames[slot],
                                    ).then((ok) {
                                      if (ok) _loadSlotsData();
                                    });
                                  }
                                },
                                child: Text(_hasPasscodes[slot] == true ? 'Ubah Kode' : 'Atur Kode'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  foregroundColor: MekaarColors.warnAmber,
                                ),
                                onPressed: () => _handleResetPasscodeViaPin(slot),
                                child: const Text('Reset via PIN'),
                              ),
                            ],
                          ),
                          const Divider(height: 18),

                          // Daftar Kontak di Slot Ini
                          Text(
                            'Kontak Tersembunyi (${slotContacts.length})',
                            style: MekaarTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: MekaarColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (slotContacts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                isSlot1
                                    ? 'Belum ada kontak. Geser kontak ke kiri pada Daftar Kontak untuk menyembunyikannya ke profil ini secara otomatis.'
                                    : 'Belum ada kontak. Pindahkan kontak dari profil lain ke profil ini.',
                                style: MekaarTypography.caption.copyWith(
                                  color: MekaarColors.textMutedOf(context),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: slotContacts.length,
                              separatorBuilder: (_, index) => const Divider(height: 8),
                              itemBuilder: (ctx, index) {
                                final contact = slotContacts[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Avatar(
                                    initial: contact.effectiveName[0],
                                    imageUrl: contact.avatarUrl,
                                    size: 34,
                                    isGuardian: contact.isGuardian,
                                  ),
                                  title: Text(
                                    contact.effectiveName,
                                    style: MekaarTypography.bodySM.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '@${contact.username}',
                                    style: MekaarTypography.caption.copyWith(
                                      color: MekaarColors.textMutedOf(context),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(SolarIconsOutline.menuDots, size: 18),
                                    tooltip: 'Opsi Kontak',
                                    onPressed: () => _showContactActionsSheet(contact),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                ],

                // Tombol Tambah Slot jika kurang dari 3
                if (_activeSlots.length < 3)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MekaarRadius.md),
                        ),
                      ),
                      icon: const Icon(SolarIconsOutline.addCircle, size: 18),
                      label: Text('Tambah Profil Slot ${_activeSlots.length + 1} (Maks 3)'),
                      onPressed: _handleAddNewSlot,
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}
