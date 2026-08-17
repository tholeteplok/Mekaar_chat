import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final TextEditingController _searchController;
  Timer? _vaultDebounceTimer;
  String _searchQuery = '';
  bool _isSearchActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vaultDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Auto-relock vault seketika saat aplikasi diminimize atau background
      if (ref.read(privateVaultUnlockedProvider)) {
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }
    }
  }

  Future<void> _checkVaultPasscode(String query) async {
    if (query.trim().isEmpty) return;
    final repo = ref.read(privateContactRepositoryProvider);
    final isMatch = await repo.verifyPasscode(query.trim());
    if (isMatch && mounted) {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
      });
      FocusScope.of(context).unfocus();
      HapticService.trigger(MekaarHapticIntent.success);
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
      MekaarSnackbar.success(
        context,
        'Koleksi Kontak & Obrolan Tersembunyi Dibuka',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final wasDuress = authState.lastUnlockWasDuress;
    final roomsAsync = ref.watch(chatRoomsProvider);
    final currentUserId = ref.watch(supabaseServiceProvider).currentUserId;
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);

    return roomsAsync.when(
      loading: () => const MekaarStateView(
        pose: MikaPose.phone,
        title: 'Memuat Kontak',
        message: 'Sedang mengambil daftar kontak Anda...',
      ),
      error: (err, stack) => MekaarStateView(
        pose: MikaPose.neutral,
        title: 'Gagal Memuat Kontak',
        message: err.toString(),
        actionLabel: 'Coba Lagi',
        onAction: () => ref.invalidate(chatRoomsProvider),
      ),
      data: (rooms) {
        // Saring data room:
        // 1. Bukan room perangkat sendiri (otherUserId == currentUserId)
        // 2. Jika vault terkunci, jangan sertakan room yang terdaftar di hiddenRoomIds
        final contactRooms = rooms.where((r) {
          if (r['otherUserId'] == currentUserId) return false;
          if (!isVaultUnlocked && hiddenRoomIds.contains(r['id'])) {
            return false;
          }
          return true;
        }).toList();

        // 3. Deduplikasi kontak unik berdasarkan otherUserId (utamakan room non-guardian/normal)
        final Map<String, Map<String, dynamic>> uniqueContacts = {};
        for (final room in contactRooms) {
          final otherUserId = room['otherUserId'] as String;
          final existing = uniqueContacts[otherUserId];
          if (existing == null ||
              (existing['isGuardian'] == true && room['isGuardian'] == false)) {
            uniqueContacts[otherUserId] = room;
          }
        }

        final allContacts =
            wasDuress ? <Map<String, dynamic>>[] : uniqueContacts.values.toList();

        // 4. Filter berdasarkan pencarian
        final filteredContacts = allContacts.where((contact) {
          final name = (contact['name'] as String).toLowerCase();
          final username = (contact['otherUsername'] as String).toLowerCase();
          final email = (contact['otherEmail'] as String).toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || username.contains(q) || email.contains(q);
        }).toList();

        // 5. Urutkan secara alfabetis berdasarkan nama
        filteredContacts.sort((a, b) => (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase()));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MekaarTabHeader(
                  title: 'Kontak',
                  isSearchActive: _isSearchActive,
                  searchController: _searchController,
                  searchHint: 'Cari nama, username, atau email...',
                  onSearchChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                    _vaultDebounceTimer?.cancel();
                    if (val.trim().length >= 4) {
                      _vaultDebounceTimer =
                          Timer(const Duration(milliseconds: 400), () {
                        _checkVaultPasscode(val);
                      });
                    }
                  },
                  onSearchClosed: () {
                    _vaultDebounceTimer?.cancel();
                    setState(() {
                      _isSearchActive = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  action: wasDuress
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                SolarIconsOutline.qrCode,
                                color: MekaarColors.primaryOf(context),
                              ),
                              tooltip: 'Kode QR & Pindai',
                              onPressed: () =>
                                  Navigator.pushNamed(context, AppRoutes.myQr),
                            ),
                            IconButton(
                              icon: Icon(
                                SolarIconsOutline.magnifier,
                                color: MekaarColors.primaryOf(context),
                              ),
                              tooltip: 'Cari Kontak',
                              onPressed: () =>
                                  setState(() => _isSearchActive = true),
                            ),
                          ],
                        ),
                ),
                // Banner Private Vault Aktif (jika vault sedang terbuka)
                if (isVaultUnlocked)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: MekaarColors.accentOf(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MekaarColors.accentOf(context).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            SolarIconsOutline.lockUnlocked,
                            color: MekaarColors.accentOf(context),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Private Vault Terbuka',
                              style: MekaarTypography.bodySM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MekaarColors.accentOf(context),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              HapticService.trigger(
                                  MekaarHapticIntent.selection);
                              ref
                                  .read(privateVaultUnlockedProvider.notifier)
                                  .state = false;
                              MekaarSnackbar.info(
                                context,
                                'Private Vault Dikunci',
                              );
                            },
                            icon: Icon(
                              SolarIconsOutline.lock,
                              size: 16,
                              color: MekaarColors.accentOf(context),
                            ),
                            label: Text(
                              'Kunci',
                              style: TextStyle(
                                color: MekaarColors.accentOf(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredContacts.isEmpty
                      ? _buildEmptyState()
                      : _buildContactsList(
                          filteredContacts, hiddenRoomIds, isVaultUnlocked),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MikaIllustration(
              pose: MikaPose.ask,
              size: 140,
              animate: true,
            ),
            const SizedBox(height: 20),
            Text(
              hasFilter ? 'Kontak Tidak Ditemukan' : 'Belum Ada Kontak',
              style: MekaarTypography.bodyMD.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MekaarColors.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Coba cari dengan kata kunci lain.'
                  : 'Mulai kirim pesan di tab Pesan untuk menambahkan kontak ke daftar Anda.',
              style: MekaarTypography.bodySM.copyWith(
                fontSize: 13.5,
                color: MekaarColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(
    List<Map<String, dynamic>> contacts,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? MekaarColors.textPrimary : const Color(0xFF1B2145);
    final mutedColor =
        isDark ? MekaarColors.textMuted : const Color(0xFF56617F);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MekaarSpacing.md,
        vertical: MekaarSpacing.xs,
      ).copyWith(bottom: 110),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final name = contact['name'] as String;
        final avatar = contact['avatar'] as String;
        final isGuardian = contact['isGuardian'] as bool? ?? false;
        final isHidden = hiddenRoomIds.contains(contact['id']);
        final username = contact['otherUsername'] as String;
        final email = contact['otherEmail'] as String;

        return AnimatedAppear(
          delay: Duration(milliseconds: (index * 40).clamp(0, 300)),
          child: CustomCard(
            margin: const EdgeInsets.only(bottom: MekaarSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.sm,
              vertical: MekaarSpacing.xs,
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.chat,
                arguments: {
                  'chatId': contact['id'],
                  'chatName': name,
                  'chatAvatar': avatar,
                  'chatAvatarUrl': contact['avatarUrl'] as String?,
                  'isGuardian': isGuardian,
                  'otherUserId': contact['otherUserId'] as String?,
                },
              );
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(
                imageUrl: contact['avatarUrl'] as String?,
                initial: avatar,
                isGuardian: isGuardian,
                size: 48,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: MekaarTypography.bodyMD.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHidden && isVaultUnlocked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MekaarColors.accentOf(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
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
                              fontWeight: FontWeight.bold,
                              color: MekaarColors.accentOf(context),
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
                        color: MekaarColors.guardianLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Guardian',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.guardianTeal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                username.isNotEmpty ? '@$username' : email,
                style: MekaarTypography.bodySM.copyWith(
                  fontSize: 13.5,
                  color: mutedColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                SolarIconsOutline.altArrowRight,
                color: mutedColor,
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }
}
