import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/sos_button.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  String _selectedTab = 'All';

  final List<String> _tabs = ['All', 'Guardian', 'Groups'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatRoomsProvider.notifier).refreshRooms();
    });
  }

  void _triggerSOS() {
    Navigator.pushNamed(context, AppRoutes.sosActive);
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomsState = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: MekaarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: MekaarColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.shield_outlined, color: MekaarColors.guardianTeal),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.guardian),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: MekaarColors.textSecondary),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                ],
              ),
            ),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: MekaarColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: MekaarColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Cari chat atau teman...',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tabs Bar
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = _selectedTab == tab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = tab),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? MekaarColors.textPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isActive ? Colors.white : MekaarColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Chat List Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(chatRoomsProvider.notifier).refreshRooms(),
                child: chatRoomsState.when(
                  data: (rooms) => _buildChatList(rooms),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Gagal memuat chat: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 4),
        child: SOSButton(
          onPressed: _triggerSOS,
          size: 72,
        ),
      ),
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> rooms) {
    // Filter rooms by query and selected tab
    final filtered = rooms.where((room) {
      final name = room['name'] as String;
      final matchQuery = name.toLowerCase().contains(_searchQuery.toLowerCase());
      
      if (!matchQuery) return false;
      
      if (_selectedTab == 'Guardian') {
        return room['isGuardian'] as bool;
      } else if (_selectedTab == 'Groups') {
        return false; // Groups not implemented in Phase 1
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: MekaarColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Belum ada chat',
              style: TextStyle(color: MekaarColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final room = filtered[index];
        final isGuardian = room['isGuardian'] as bool;
        final lastMsgTime = room['timestamp'] as DateTime;
        final timeStr = DateFormat('HH:mm').format(lastMsgTime);

        return CustomCard(
          padding: EdgeInsets.zero,
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.chat,
              arguments: {
                'chatId': room['id'],
                'chatName': room['name'],
                'chatAvatar': room['avatar'],
                'isGuardian': isGuardian,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Avatar(
                  initial: room['avatar'] as String,
                  size: 48,
                  isGuardian: isGuardian,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            room['name'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MekaarColors.textPrimary,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: MekaarColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room['lastMessage'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MekaarColors.textSecondary,
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
        );
      },
    );
  }
}
