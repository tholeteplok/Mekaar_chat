import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final wasDuress = authState.lastUnlockWasDuress;
    final roomsAsync = ref.watch(chatRoomsProvider);
    final currentUserId = ref.watch(supabaseServiceProvider).currentUserId;

    return roomsAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: MekaarColors.softCoral),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text(
            'Gagal memuat kontak: $err',
            style: const TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ),
      data: (rooms) {
        // Saring data room:
        // 1. Bukan room perangkat sendiri (otherUserId == currentUserId)
        final contactRooms = rooms.where((r) => r['otherUserId'] != currentUserId).toList();

        // 2. Deduplikasi kontak unik berdasarkan otherUserId (utamakan room non-guardian/normal)
        final Map<String, Map<String, dynamic>> uniqueContacts = {};
        for (final room in contactRooms) {
          final otherUserId = room['otherUserId'] as String;
          final existing = uniqueContacts[otherUserId];
          if (existing == null || (existing['isGuardian'] == true && room['isGuardian'] == false)) {
            uniqueContacts[otherUserId] = room;
          }
        }

        final allContacts = wasDuress ? <Map<String, dynamic>>[] : uniqueContacts.values.toList();

        // 3. Filter berdasarkan pencarian
        final filteredContacts = allContacts.where((contact) {
          final name = (contact['name'] as String).toLowerCase();
          final username = (contact['otherUsername'] as String).toLowerCase();
          final email = (contact['otherEmail'] as String).toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || username.contains(q) || email.contains(q);
        }).toList();

        // 4. Urutkan secara alfabetis berdasarkan nama
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
                const MekaarTabHeader(title: 'Kontak'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MekaarSearchField(
                    hintText: 'Cari nama, username, atau email...',
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredContacts.isEmpty
                      ? _buildEmptyState()
                      : _buildContactsList(filteredContacts),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MekaarColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Coba cari dengan kata kunci lain.'
                  : 'Mulai kirim pesan di tab Pesan untuk menambahkan kontak ke daftar Anda.',
              style: const TextStyle(
                fontSize: 13,
                color: MekaarColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(List<Map<String, dynamic>> contacts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8).copyWith(bottom: 110),
      itemCount: contacts.length,
      separatorBuilder: (context, index) => const Divider(
        color: MekaarColors.borderLight,
        height: 1,
        indent: 68,
      ),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final name = contact['name'] as String;
        final avatar = contact['avatar'] as String;
        final isGuardian = contact['isGuardian'] as bool? ?? false;
        final username = contact['otherUsername'] as String;
        final email = contact['otherEmail'] as String;

        return AnimatedAppear(
          delay: Duration(milliseconds: (index * 40).clamp(0, 300)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: Avatar(
              initial: avatar,
              isGuardian: isGuardian,
              size: 48,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: MekaarColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isGuardian) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MekaarColors.guardianLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Guardian',
                      style: TextStyle(
                        color: MekaarColors.guardianTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              username.isNotEmpty ? '@$username' : email,
              style: const TextStyle(
                fontSize: 12,
                color: MekaarColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.chat,
                arguments: {
                  'chatId': contact['id'],
                  'chatName': name,
                  'chatAvatar': avatar,
                  'isGuardian': isGuardian,
                  'otherUserId': contact['otherUserId'] as String?,
                },
              );
            },
          ),
        );
      },
    );
  }
}
