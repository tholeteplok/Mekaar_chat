import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../../../core/widgets/scroll_to_bottom_button.dart';
import '../../../data/repositories/forwarding_protection_repository.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/e2ee_preparation_banner.dart';
import '../providers/e2ee_room_status_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/media_upload_service.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../../../core/routes/app_routes.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final bool isGroup;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.isGroup = false,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

enum _ChatItemKind { message, dateSeparator }

class _ChatItemEntry {
  final _ChatItemKind kind;
  final Message? message;
  final DateTime? date;

  const _ChatItemEntry.message(this.message)
      : kind = _ChatItemKind.message,
        date = null;

  const _ChatItemEntry.dateSeparator(this.date)
      : kind = _ChatItemKind.dateSeparator,
        message = null;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isViewOnce = false;
  Message? _replyMessage;
  Message? _editingMessage;
  DateTime? _otherLastRead;
  DateTime? _otherLastSeen;
  int _autoDeleteHours = 0;
  final ValueNotifier<bool> _showScrollButton = ValueNotifier<bool>(false);
  int _newMessageCount = 0;
  Map<String, String> _participantNames = {};
  Timer? _purgeTimer;

  Future<void> _loadGroupParticipants() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final details = await repo.getGroupDetails(widget.chatId);
      if (details != null && mounted) {
        final participants = (details['participants'] as List?) ?? [];
        final names = <String, String>{};
        for (final p in participants) {
          final pid = p['profile_id'] as String?;
          final profile = p['public_profiles'] as Map<String, dynamic>?;
          if (pid != null && profile != null) {
            final name = (profile['display_name'] as String?)?.isNotEmpty == true
                ? profile['display_name'] as String
                : profile['full_name'] as String? ??
                    profile['username'] as String? ??
                    'Anggota';
            names[pid] = name;
          }
        }
        setState(() => _participantNames = names);
      }
    } catch (_) {}
  }

  void _onScrollChanged() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.minScrollExtent + 200;
    if (_showScrollButton.value != atBottom) {
      _showScrollButton.value = atBottom;
      if (!atBottom && _newMessageCount > 0) {
        setState(() => _newMessageCount = 0);
      }
    }
  }

  Timer? _presenceHeartbeatTimer;

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final repo = ref.read(chatRepositoryProvider);
      await repo.updateLastSeen();
      if (widget.otherUserId != null) {
        final lastSeen = await repo.getLastSeen(widget.otherUserId!);
        if (mounted) {
          setState(() {
            _otherLastSeen = lastSeen;
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollChanged);
    // Tandai room ini sebagai aktif agar listener notifikasi pesan tahu
    // untuk tidak memunculkan notif saat user sedang melihat percakapan.
    ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
    _startPresenceHeartbeat();

    // Timer periodik pembersihan pesan kedaluwarsa (client guard)
    _purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      try {
        ref.read(chatRepositoryProvider).purgeExpiredMessages();
      } catch (_) {}
    });

    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);
      
      // Muat preferensi pesan menghilang level room (tersinkronisasi untuk kedua pihak)
      final roomAutoDelete = await repo.getRoomDisappearingHours(widget.chatId);
      
      // Muat preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
      bool savedViewOnce = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        savedViewOnce = prefs.getBool('room_view_once_${widget.chatId}') ?? false;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _autoDeleteHours = roomAutoDelete;
        _isViewOnce = savedViewOnce;
      });

      // Best-effort purge pesan kedaluwarsa saat pertama buka chat
      try {
        await repo.purgeExpiredMessages();
      } catch (_) {}
      _otherLastRead = await repo.getOtherParticipantLastRead(widget.chatId);
      if (widget.otherUserId != null) {
        _otherLastSeen = await repo.getLastSeen(widget.otherUserId!);
      }
      if (widget.isGroup) {
        _loadGroupParticipants();
      }
      repo.updateLastSeen();
    });
  }

  void _onTextChanged() {
    final isTyping = _textController.text.isNotEmpty;
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(isTyping);
  }

  /// Format presence subtitle: online (< 2 min) > last seen (formatted) > hidden privacy
  String _formatPresenceSubtitle() {
    // Jika null: pengguna menyembunyikan "terakhir dilihat" (enforce di server via RPC get_last_seen_for)
    if (_otherLastSeen == null) return 'Terakhir dilihat baru-baru ini';

    final now = DateTime.now();
    final lastSeen = _otherLastSeen!;
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 2) {
      return 'Online';
    }

    final isSameDay = now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == lastSeen.year &&
        yesterday.month == lastSeen.month &&
        yesterday.day == lastSeen.day;

    final hourStr = lastSeen.hour.toString().padLeft(2, '0');
    final minuteStr = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (isSameDay) {
      return 'Terakhir dilihat hari ini pukul $timeStr';
    } else if (isYesterday) {
      return 'Terakhir dilihat kemarin pukul $timeStr';
    } else if (now.year == lastSeen.year) {
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final monthName = monthNames[lastSeen.month - 1];
      return 'Terakhir dilihat ${lastSeen.day} $monthName pukul $timeStr';
    } else {
      final dayStr = lastSeen.day.toString().padLeft(2, '0');
      final monthStr = lastSeen.month.toString().padLeft(2, '0');
      return 'Terakhir dilihat $dayStr/$monthStr/${lastSeen.year}';
    }
  }

  bool get _isCurrentlyOnline {
    if (_otherLastSeen == null) return false;
    return DateTime.now().difference(_otherLastSeen!).inMinutes < 2;
  }

  @override
  void dispose() {
    _presenceHeartbeatTimer?.cancel();
    _purgeTimer?.cancel();
    // Hentikan live location sharing jika masih aktif saat meninggalkan room
    ref.read(chatActionsProvider).stopLiveLocationShare();
    // Bersihkan penanda room aktif agar notif pesan kembali aktif
    // saat user meninggalkan percakapan ini.
    if (ref.read(activeRoomIdProvider) == widget.chatId) {
      ref.read(activeRoomIdProvider.notifier).state = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    _showScrollButton.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Tactile Feedback 0ms: Pemicuan getaran ringan instan saat tombol diketuk
    HapticService.trigger(MekaarHapticIntent.selection);

    final actions = ref.read(chatActionsProvider);

    // ── Mode 1: Edit Pesan ──
    if (_editingMessage != null) {
      final msgToEdit = _editingMessage!;
      if (!actions.canEdit(msgToEdit, isGuardianRoom: widget.isGuardian)) {
        _textController.clear();
        setState(() => _editingMessage = null);
        return;
      }

      final originalText = text;
      final originalMsg = msgToEdit;

      _textController.clear();
      setState(() => _editingMessage = null);
      ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);

      try {
        await actions.editMessage(
          msgToEdit.id,
          text,
          isGuardianRoom: widget.isGuardian,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _textController.text = originalText;
            _editingMessage = originalMsg;
          });
          MekaarSnackbar.error(context, 'Gagal menyimpan pesan: $e');
        }
      }
      return;
    }

    // ── Mode 2: Kirim Pesan Baru (Optimistic Input Clearing) ──
    final textToSend = text;
    final replyToMessage = _replyMessage;
    final isViewOnceToSend = _isViewOnce;

    // Pengosongan Input Bar & Reset State UI Secara Instan (0ms Delay bagi Pengguna)
    _textController.clear();
    setState(() {
      _replyMessage = null;
    });
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);
    _scrollToBottom();

    try {
      await actions.sendMessage(
        widget.chatId,
        textToSend,
        type: MessageType.text,
        isViewOnce: isViewOnceToSend,
        replyToId: replyToMessage?.id,
        autoDeleteHours: _autoDeleteHours,
      );
    } catch (e) {
      // Fail-Safe Restoration: Kembalikan teks dan state bila pengiriman jaringan gagal
      if (mounted) {
        setState(() {
          _textController.text = textToSend;
          _replyMessage = replyToMessage;
          _isViewOnce = isViewOnceToSend;
        });
        MekaarSnackbar.error(context, 'Gagal mengirim pesan: $e');
      }
    }
  }

  Future<void> _handleSendMedia(File file, MessageType type) async {
    String? uploadedUrl;
    final uploader = MediaUploadService(Supabase.instance.client);

    try {
      String? fileKeyB64;
      String url;

      // Check whether room supports E2EE (peer key exists) without wasteful dummy encryption
      final peerKey = widget.otherUserId != null 
          ? await E2eeService.instance.getPeerPublicKey(widget.otherUserId!)
          : null;
      if (peerKey != null && peerKey.isNotEmpty) {
        // Kamar chat mendukung E2EE, enkripsi & unggah media
        final result = await uploader.uploadEncryptedChatMedia(file, widget.chatId);
        url = result.url;
        fileKeyB64 = result.keyB64;
      } else {
        // Fallback: unggah biasa
        url = await uploader.uploadChatMedia(file, widget.chatId);
      }

      uploadedUrl = url;
      final isViewOnceToSend = _isViewOnce;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            fileKeyB64 ?? '',
            mediaUrl: url,
            type: type,
            isViewOnce: isViewOnceToSend,
            autoDeleteHours: _autoDeleteHours,
          );
      _scrollToBottom();
    } catch (e) {
      // Cleanup uploaded media if message creation fails
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        try {
          await uploader.deleteMediaByUrl(uploadedUrl);
        } catch (_) {}
      }
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengirim media: $e');
      }
    }
  }

  Future<void> _handleSendLocation() async {
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) return;
      }

      final locationData = await location.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      if (lat == null || lng == null) return;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            '$lat, $lng',
            type: MessageType.location,
            autoDeleteHours: _autoDeleteHours,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mendapatkan lokasi: $e');
      }
    }
  }

  Future<void> _handleShareLiveLocation(int durationMinutes) async {
    try {
      await ref
          .read(chatActionsProvider)
          .shareLiveLocation(widget.chatId, durationMinutes);
      if (mounted) {
        MekaarSnackbar.success(context, 'Lokasi live dibagikan selama $durationMinutes menit');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal membagikan lokasi live: $e');
      }
    }
  }

  void _handleDeleteMessage(Message msg) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus untuk Saya?',
      message: 'Pesan akan disembunyikan untuk Anda saja. Lawan bicara tetap dapat melihat pesan ini.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(chatActionsProvider).hideMessageForMe(msg.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text(
            'Hapus',
            style: TextStyle(color: MekaarColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _handleUnsendMessage(Message msg) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Tarik Pesan?',
      message: widget.isGuardian
          ? 'Konten pesan akan hilang dari layar. Log sistem tetap mencatat snapshot penghapusan demi integritas bukti.'
          : 'Pesan akan dihapus untuk semua orang. Jika belum dibaca, pesan ini akan ditarik tanpa jejak.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(chatActionsProvider).deleteMessageForEveryone(msg.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text(
            'Tarik Pesan',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _handleReactToMessage(Message msg, String emoji) {
    ref.read(chatActionsProvider).reactToMessage(msg.id, emoji);
  }

  void _handleForwardMessage(Message msg) {
    final rooms = ref.read(chatRoomsProvider).value ?? [];
    final targets = rooms.where((r) => r['id'] != widget.chatId).toList();

    final hasTargets = targets.isNotEmpty;

    MekaarBottomSheet.show(
      context: context,
      title: 'Teruskan ke',
      builder: (ctx) => hasTargets
          ? ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: targets.map((room) {
                final name = room['name'] as String? ?? 'User';
                final avatar = room['avatar'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      avatar.isNotEmpty ? avatar : name[0],
                      style: const TextStyle(color: MekaarColors.textPrimary),
                    ),
                  ),
                  title: Text(name),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(chatActionsProvider)
                          .forwardMessage(msg, room['id'] as String);
                    } catch (e) {
                      if (ctx.mounted) {
                        MekaarSnackbar.error(ctx, 'Gagal meneruskan pesan: $e');
                      }
                      return;
                    }
                    if (ctx.mounted) {
                      MekaarSnackbar.success(ctx, 'Pesan diteruskan ke $name');
                    }
                  },
                );
              }).toList(),
            )
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada chat lain untuk meneruskan pesan.',
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  void _toggleViewOnce() async {
    final newValue = !_isViewOnce;
    setState(() => _isViewOnce = newValue);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('room_view_once_${widget.chatId}', newValue);
    } catch (_) {}
    if (!mounted) return;
    MekaarSnackbar.info(
      context,
      newValue
          ? 'Mode Sekali Lihat Aktif (Media akan hilang setelah dibuka).'
          : 'Mode Sekali Lihat Dinonaktifkan.',
    );
  }

  void _setAutoDeleteHours(int hours) {
    setState(() => _autoDeleteHours = hours);
  }

  String _autoDeleteLabel() {
    if (_autoDeleteHours <= 0) return 'Mati';
    if (_autoDeleteHours == 1) return '1 Jam';
    if (_autoDeleteHours == 24) return '1 Hari';
    if (_autoDeleteHours == 168) return '7 Hari';
    return '$_autoDeleteHours Jam';
  }

  Future<void> _showAutoDeleteMenu() async {
    final choice = await MekaarBottomSheet.show<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (1, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (24, '1 Hari', 'Pesan otomatis terhapus setelah 1 hari'),
          (168, '7 Hari', 'Pesan otomatis terhapus setelah 7 hari'),
        ];
        return MekaarBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pesan Menghilang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == _autoDeleteHours;
                return ListTile(
                  leading: Icon(
                    selected ? SolarIconsBold.history : SolarIconsOutline.history,
                    color: selected ? MekaarColors.softCoral : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? const Icon(MekaarIcons.check, color: MekaarColors.softCoral)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt.$1),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choice != null) {
      final previousHours = _autoDeleteHours;
      _setAutoDeleteHours(choice);
      try {
        await ref
            .read(chatRepositoryProvider)
            .updateRoomDisappearingHours(widget.chatId, choice);
      } catch (e) {
        // Rollback tampilan optimis -- jangan biarkan UI menunjukkan
        // pilihan baru seolah tersimpan padahal RPC gagal (ini persis
        // pola yang sebelumnya membuat pengaturan tampak "hilang"/
        // "terkunci" tanpa disadari, lihat migrations/40_fix_room_
        // participant_rpcs_search_path.sql untuk akar masalahnya).
        if (mounted) {
          _setAutoDeleteHours(previousHours);
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pengaturan pesan menghilang: $e',
          );
        }
      }
    }
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || widget.otherUserId == null) {
      MekaarSnackbar.error(context, 'Panggilan tidak tersedia untuk obrolan ini.');
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.call,
      arguments: {
        'roomId': widget.chatId,
        'chatName': widget.chatName,
        'callerId': currentUserId,
        'receiverId': widget.otherUserId!,
        'isCaller': true,
        'callType': callType,
      },
    );
  }

  void _confirmClearHistory() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Bersihkan Riwayat?',
      message: widget.isGuardian
          ? 'Seluruh riwayat chat akan dibersihkan dari tampilan Anda, namun log percakapan tetap diarsipkan demi kepatuhan Room Guardian.'
          : 'Seluruh riwayat chat di ruangan ini akan dibersihkan untuk Anda.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await ref.read(chatActionsProvider).clearChatHistory(widget.chatId);
            if (!mounted) return;
            MekaarSnackbar.success(context, 'Riwayat obrolan dibersihkan.');
          },
          child: const Text(
            'Bersihkan',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteChat() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Chat?',
      message:
          'Apakah Anda yakin ingin menghapus seluruh obrolan ini? Obrolan akan hilang dari daftar chat Anda.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await ref.read(chatActionsProvider).deleteChat(widget.chatId);
            if (!mounted) return;
            Navigator.pop(context); // Exit chat room to ChatListScreen
          },
          child: const Text(
            'Hapus',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _showE2eeInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(SolarIconsOutline.shieldKeyhole, color: MekaarColors.guardianTeal),
            SizedBox(width: 8),
            Text('Mekaar Aegis Shield (E2EE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesan dan panggilan dalam chat ini dilindungi oleh Mekaar Aegis Shield dengan enkripsi ujung-ke-ujung (E2EE) menggunakan pasangan kunci asimetris X25519 & ChaCha20-Poly1305.',
              style: TextStyle(color: MekaarColors.textPrimaryOf(context), fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Batasan Forward Secrecy:',
              style: TextStyle(color: MekaarColors.warnAmber, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'MEKAAR saat ini tidak menggunakan rotasi kunci otomatis (Forward Secrecy). Jika kunci privat salah satu pihak bocor di masa mendatang, pesan-pesan lama dalam ruang obrolan ini secara teoritis dapat didekripsi. Amankan PIN dan perangkat Anda.',
              style: TextStyle(color: MekaarColors.textMutedOf(context), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: MekaarColors.guardianTeal)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e2eeStatus = ref.watch(e2eeRoomStatusProvider(widget.chatId));
    final isE2eeReady = e2eeStatus == E2eeRoomStatus.ready;

    final messagesStream = ref.watch(chatMessagesProvider(widget.chatId));
    final protectionAsync = ref.watch(
      roomScreenProtectionProvider(widget.chatId),
    );
    final protection = protectionAsync.valueOrNull;

    final forwardingProtectionAsync = ref.watch(
      roomForwardingProtectionProvider(widget.chatId),
    );
    final forwardingProtection = forwardingProtectionAsync.valueOrNull;
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);
    final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);

    final topAreaHeight = MediaQuery.of(context).padding.top + kToolbarHeight + 16.0;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return MekaarScaffold(
      flat: false,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Layer 0: Wallpaper/Background ──
          _buildWallpaperBackground(chatPref),

          // ── Layer 1: Daftar Pesan (full screen, padding atas & bawah) ──
          Positioned.fill(
            child: Column(
              children: [
                // Banner E2EE & proteksi harus di bawah header floating agar
                // tidak tertimpa atau terlalu ke atas
                SizedBox(height: topAreaHeight),
                E2eePreparationBanner(status: e2eeStatus),
                if (protection?.effective ?? true)
                  ScreenProtectionStatusBadge(
                    label: protection?.statusLabel ?? 'Proteksi ruang aktif',
                  ),
                Expanded(
                  child: messagesStream.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const MekaarStateView(
                          pose: MikaPose.sleep,
                          title: 'Belum Ada Pesan',
                          message: 'Belum ada pesan. Kirim pesan pertama!',
                        );
                      }

                      final reversed = messages.reversed.toList();
                      final itemEntries = _buildItemEntries(reversed);
                      final messageMap = {for (var m in messages) m.id: m};

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        // Padding bawah memberi ruang untuk composer floating + inset keyboard
                        padding: EdgeInsets.only(top: 8, bottom: 130 + keyboardHeight),
                        itemCount: itemEntries.length,
                        itemBuilder: (context, index) {
                          return _buildLazyMessageItem(
                            itemEntries[index],
                            currentUserId,
                            actions,
                            messageMap,
                            forwardingProtection: forwardingProtection,
                            roomThemeSpec: roomThemeSpec,
                          );
                        },
                      );
                    },
                    loading: () => const MekaarStateView(
                      pose: MikaPose.neutral,
                      title: 'Memuat',
                      message: 'Memuat pesan...',
                    ),
                    error: (err, stack) => MekaarStateView(
                      pose: MikaPose.huft,
                      title: 'Gagal Memuat',
                      message: 'Gagal memuat pesan: $err',
                      actionLabel: 'Coba Lagi',
                      onAction: () => ref.invalidate(
                        chatMessagesProvider(widget.chatId),
                      ),
                      icon: SolarIconsOutline.refresh,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isTyping = ref.watch(typingStateProvider(widget.chatId));
                    if (!isTyping) return const SizedBox.shrink();
                    return TypingIndicator(dotColor: roomThemeSpec.primaryAccentColor);
                  },
                ),
              ],
            ),
          ),

          // ── Layer 2: Composer Floating (bawah) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom,
            child: ChatComposer(
              controller: _textController,
              replyMessage: _replyMessage,
              editingMessage: _editingMessage,
              enabled: isE2eeReady,
              roomThemeSpec: roomThemeSpec,
              onSend: _handleSend,
              onCancelReply: () => setState(() => _replyMessage = null),
              onCancelEdit: () {
                setState(() => _editingMessage = null);
                _textController.clear();
              },
              onSendMedia: _handleSendMedia,
              onSendLocation: _handleSendLocation,
              onShareLiveLocation: _handleShareLiveLocation,
            ),
          ),

          // ── Layer 5: Scroll-to-bottom button ──
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: _showScrollButton,
                builder: (context, showButton, _) {
                  return ScrollToBottomButton(
                    visible: showButton,
                    newMessageCount: _newMessageCount,
                    accentColor: roomThemeSpec.primaryAccentColor,
                    iconColor: roomThemeSpec.iconColor,
                    onTap: () {
                      _scrollToBottom();
                      setState(() => _newMessageCount = 0);
                    },
                  );
                },
              ),
            ),
          ),

          // ── Layer 4: Header Floating (atas) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final isTyping = ref.watch(typingStateProvider(widget.chatId));
                    return CustomAppBar(
                      isFloating: true,
                      title: widget.chatName,
                      avatarInitial: widget.chatAvatar,
                      avatarUrl: widget.chatAvatarUrl,
                      isGuardian: widget.isGuardian,
                      showOnlineIndicator: true,
                      isOnline: _isCurrentlyOnline || isTyping,
                      subtitle: isTyping ? 'sedang mengetik...' : _formatPresenceSubtitle(),
                      glassBorder: roomThemeSpec.glassBorder,
                      glassBackgroundColor: roomThemeSpec.glassBackgroundColor,
                      iconColor: roomThemeSpec.iconColor,
                      textColor: roomThemeSpec.textColor,
                      subtitleColor: roomThemeSpec.subtitleColor,
                      onAvatarTap: widget.isGroup
                          ? () => Navigator.pushNamed(
                                context,
                                AppRoutes.groupDetails,
                                arguments: {
                                  'roomId': widget.chatId,
                                  'groupName': widget.chatName,
                                  'groupAvatarUrl': widget.chatAvatarUrl,
                                },
                              )
                          : (widget.otherUserId != null
                              ? () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.contactSettings,
                                    arguments: {
                                      'roomId': widget.chatId,
                                      'chatName': widget.chatName,
                                      'chatAvatar': widget.chatAvatar,
                                      'otherUserId': widget.otherUserId!,
                                      'isGuardian': widget.isGuardian,
                                    },
                                  )
                              : null),
                      actions: [
                        // Voice Call icon
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.phone,
                            color: roomThemeSpec.primaryAccentColor,
                          ),
                          onPressed: () => _initiateCall('voice'),
                          tooltip: 'Panggilan Suara',
                        ),
                        // Actions Popup Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            SolarIconsOutline.menuDots,
                            color: roomThemeSpec.primaryAccentColor,
                          ),
                          onSelected: (value) async {
                            if (value == 'video') {
                              _initiateCall('video');
                            } else if (value == 'theme') {
                              Navigator.pushNamed(context, AppRoutes.chatThemeSettings);
                            } else if (value == 'clear') {
                              _confirmClearHistory();
                            } else if (value == 'e2ee_info') {
                              _showE2eeInfoDialog();
                            } else if (value == 'delete') {
                              _confirmDeleteChat();
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'e2ee_info',
                              child: Row(
                                children: [
                                  Icon(
                                    SolarIconsOutline.shieldKeyhole,
                                    size: 20,
                                    color: MekaarColors.guardianTeal,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Informasi Enkripsi E2EE'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'video',
                              child: Row(
                                children: [
                                  Icon(
                                    SolarIconsOutline.videocamera,
                                    size: 20,
                                    color: MekaarColors.textPrimaryOf(context),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Panggilan Video'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'theme',
                              child: Row(
                                children: [
                                  Icon(
                                    SolarIconsOutline.palette,
                                    size: 20,
                                    color: MekaarColors.textPrimaryOf(context),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Tema & Wallpaper Chat'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(
                                    SolarIconsOutline.eraser,
                                    size: 20,
                                    color: MekaarColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Bersihkan Obrolan'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    SolarIconsOutline.trashBinTrash,
                                    size: 20,
                                    color: MekaarColors.sosRed,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hapus Chat',
                                    style: TextStyle(color: MekaarColors.sosRed),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                _buildQuickPrivacyBar(
                  isScreenProtectionOn: protection?.callerEnabled ?? true,
                  isForwardingProtectionOn: forwardingProtection?.callerEnabled ?? false,
                  isAutoDeleteOn: _autoDeleteHours > 0,
                  isViewOnceOn: _isViewOnce,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// Buat daftar data entri secara cepat (O(N) data pointer tanpa alokasi widget eager).
  List<_ChatItemEntry> _buildItemEntries(List<Message> reversedMessages) {
    final entries = <_ChatItemEntry>[];
    DateTime? lastDate;

    for (var i = 0; i < reversedMessages.length; i++) {
      final msg = reversedMessages[i];
      final msgDate = DateTime(
        msg.createdAt.year,
        msg.createdAt.month,
        msg.createdAt.day,
      );

      // Sisipkan pemisah tanggal jika hari berubah
      if (lastDate == null || msgDate != lastDate) {
        entries.add(_ChatItemEntry.dateSeparator(msg.createdAt));
        lastDate = msgDate;
      }

      entries.add(_ChatItemEntry.message(msg));
    }
    return entries;
  }

  /// Bangun widget pesan individual secara lazy pada index viewport yang sedang aktif.
  Widget _buildLazyMessageItem(
    _ChatItemEntry entry,
    String? currentUserId,
    ChatActionsNotifier actions,
    Map<String, Message> messageMap, {
    RoomForwardingProtection? forwardingProtection,
    ChatRoomThemeSpec? roomThemeSpec,
  }) {
    if (entry.kind == _ChatItemKind.dateSeparator) {
      return ChatDateSeparator(
        date: entry.date!,
        accentColor: roomThemeSpec?.secondaryAccentColor,
        textColor: roomThemeSpec?.textColor,
      );
    }

    final msg = entry.message!;
    final isMe = msg.senderId == currentUserId;
    final canEdit = actions.canEdit(
      msg,
      isGuardianRoom: widget.isGuardian,
    );

    Message? replyToMsg;
    String? replyToSender;
    if (msg.replyToId != null) {
      replyToMsg = messageMap[msg.replyToId];
      if (replyToMsg != null) {
        if (replyToMsg.senderId == currentUserId) {
          replyToSender = 'Anda';
        } else {
          replyToSender = _participantNames[replyToMsg.senderId] ?? 'Pengirim';
        }
      }
    }

    final bubble = ChatBubble(
      message: msg,
      isMe: isMe,
      canDelete: true, // Semua pesan bisa dihapus secara lokal (hide for me)
      canUnsend: isMe, // Hanya pengirim yang bisa tarik pesan (delete for everyone)
      canEdit: isMe && canEdit,
      canForward: actions.canForward(
        msg,
        forwardingProtectionActive:
            forwardingProtection?.effective ?? false,
      ),
      otherLastReadAt: _otherLastRead,
      showReadReceipts:
          ref.watch(authProvider).profile?.readReceiptsEnabled ?? true,
      senderName: widget.isGroup ? _participantNames[msg.senderId] : null,
      replyToMessage: replyToMsg,
      replyToSenderName: replyToSender,
      onDelete: () => _handleDeleteMessage(msg),
      onUnsend: () => _handleUnsendMessage(msg),
      onReply: (replyMsg) {
        setState(() {
          _replyMessage = replyMsg;
          _editingMessage = null;
        });
      },
      onEdit: (editMsg, newContent) {
        if (!actions.canEdit(
          editMsg,
          isGuardianRoom: widget.isGuardian,
        )) {
          return;
        }
        ref
            .read(chatActionsProvider)
            .editMessage(
              editMsg.id,
              newContent,
              isGuardianRoom: widget.isGuardian,
            );
      },
      onForward: (forwardingProtection?.effective ?? false)
          ? null
          : (forwardMsg) => _handleForwardMessage(forwardMsg),
      onReact: (reactMsg, emoji) =>
          _handleReactToMessage(reactMsg, emoji),
    );

    // Bungkus dengan RepaintBoundary untuk isolasi repaint dan SwipeToReply
    return RepaintBoundary(
      child: _SwipeToReplyWrapper(
        onReply: () => setState(() {
          _replyMessage = msg;
          _editingMessage = null;
        }),
        child: AnimatedAppear(
          key: ValueKey('bubble_${msg.id}'),
          child: bubble,
        ),
      ),
    );
  }

  Widget _buildQuickPrivacyBar({
    required bool isScreenProtectionOn,
    required bool isForwardingProtectionOn,
    required bool isAutoDeleteOn,
    required bool isViewOnceOn,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MekaarColors.cardDark.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Proteksi Layar
          InkWell(
            onTap: () async {
              final nextValue = !isScreenProtectionOn;
              try {
                await ref
                    .read(screenProtectionControllerProvider)
                    .setRoomPreference(widget.chatId, nextValue);
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isScreenProtectionOn
                        ? SolarIconsBold.shieldCheck
                        : SolarIconsOutline.shieldCross,
                    size: 15,
                    color: isScreenProtectionOn
                        ? MekaarColors.softCoral
                        : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Proteksi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isScreenProtectionOn ? FontWeight.bold : FontWeight.normal,
                      color: isScreenProtectionOn
                          ? MekaarColors.softCoral
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Larang Teruskan
          InkWell(
            onTap: () async {
              final nextValue = !isForwardingProtectionOn;
              try {
                await ref
                    .read(forwardingProtectionControllerProvider)
                    .setRoomPreference(widget.chatId, nextValue);
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isForwardingProtectionOn
                        ? SolarIconsBold.forbiddenCircle
                        : SolarIconsOutline.forward,
                    size: 15,
                    color: isForwardingProtectionOn
                        ? MekaarColors.softCoral
                        : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Larang Teruskan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isForwardingProtectionOn ? FontWeight.bold : FontWeight.normal,
                      color: isForwardingProtectionOn
                          ? MekaarColors.softCoral
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Pesan Menghilang
          InkWell(
            onTap: _showAutoDeleteMenu,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAutoDeleteOn
                        ? SolarIconsBold.history
                        : SolarIconsOutline.history,
                    size: 15,
                    color: isAutoDeleteOn
                        ? MekaarColors.softCoral
                        : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAutoDeleteOn ? _autoDeleteLabel() : 'Menghilang',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isAutoDeleteOn ? FontWeight.bold : FontWeight.normal,
                      color: isAutoDeleteOn
                          ? MekaarColors.softCoral
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Sekali Lihat
          InkWell(
            onTap: _toggleViewOnce,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isViewOnceOn
                        ? SolarIconsBold.eyeClosed
                        : SolarIconsOutline.eyeClosed,
                    size: 15,
                    color: isViewOnceOn
                        ? MekaarColors.softCoral
                        : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sekali Lihat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isViewOnceOn ? FontWeight.bold : FontWeight.normal,
                      color: isViewOnceOn
                          ? MekaarColors.softCoral
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperBackground(ChatThemePreference pref) {
    return ChatPresetResolver.buildWallpaper(pref, context);
  }
}

/// Gesture wrapper untuk swipe-to-reply pada bubble chat.
/// Swipe dari kanan ke kiri: reply.
class _SwipeToReplyWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(child.key),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        onReply();
        return false; // Never actually dismiss — just trigger reply
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 32),
        color: MekaarColors.guardianTeal.withValues(alpha: 0.15),
        child: const Icon(
          SolarIconsOutline.reply,
          color: MekaarColors.guardianTeal,
          size: 24,
        ),
      ),
      child: child,
    );
  }
}

