import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
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
import '../providers/chat_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/e2ee_preparation_banner.dart';
import '../providers/e2ee_room_status_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/media_upload_service.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../core/routes/app_routes.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isViewOnce = false;
  Message? _replyMessage;
  Message? _editingMessage;
  DateTime? _otherLastRead;
  DateTime? _otherLastSeen;
  // ignore: prefer_final_fields — mutable: updated when partner sends typing event
  bool _partnerIsTyping = false;
  int _autoDeleteHours = 0;
  bool _showScrollButton = false;
  int _newMessageCount = 0;

  void _onScrollChanged() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.minScrollExtent + 200;
    if (_showScrollButton != atBottom) {
      setState(() {
        _showScrollButton = atBottom;
        if (!atBottom) _newMessageCount = 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollChanged);
    // Tandai room ini sebagai aktif agar listener notifikasi pesan tahu
    // untuk tidak memunculkan notif saat user sedang melihat percakapan.
    ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);
      // Muat preferensi per-kontak: pesan menghilang override
      final preferences = await repo.getRoomPreferences(widget.chatId);
      if (!mounted) return;
      _autoDeleteHours = preferences?.disappearingOverrideHours ?? 0;
      // Best-effort purge pesan kedaluwarsa (authoritative via cron Supabase).
      try {
        await repo.purgeExpiredMessages();
      } catch (_) {}
      _otherLastRead = await repo.getOtherParticipantLastRead(widget.chatId);
      if (widget.otherUserId != null) {
        _otherLastSeen = await repo.getLastSeen(widget.otherUserId!);
      }
      repo.updateLastSeen();
      if (mounted) setState(() {});
    });
  }

  void _onTextChanged() {
    // Local typing indicator — broadcast event to partner via Realtime
    // For now set local state only; Realtime Broadcast can be wired later
    // without changing the UI contract.
    final isTyping = _textController.text.isNotEmpty;
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(isTyping);
  }

  /// Build presence subtitle: typing > online (< 5 min) > last seen > hidden
  String _buildPresenceSubtitle() {
    if (_partnerIsTyping) return 'sedang mengetik...';
    // Jika null, bisa jadi belum pernah online ATAU pengguna menyembunyikan
    // "terakhir dilihat" (enforce di server via get_last_seen_for). Sembunyikan
    // detail demi privasi.
    if (_otherLastSeen == null) return '';
    final diff = DateTime.now().difference(_otherLastSeen!);
    if (diff.inMinutes < 5) return 'Online';
    if (diff.inMinutes < 60) {
      return 'Terakhir dilihat ${diff.inMinutes} menit lalu';
    }
    if (diff.inHours < 24) return 'Terakhir dilihat ${diff.inHours} jam lalu';
    final days = diff.inDays;
    if (days == 1) return 'Terakhir dilihat kemarin';
    return 'Terakhir dilihat $days hari lalu';
  }

  bool get _isCurrentlyOnline {
    if (_otherLastSeen == null) return false;
    return DateTime.now().difference(_otherLastSeen!).inMinutes < 5;
  }

  @override
  void dispose() {
    // Bersihkan penanda room aktif agar notif pesan kembali aktif
    // saat user meninggalkan percakapan ini.
    if (ref.read(activeRoomIdProvider) == widget.chatId) {
      ref.read(activeRoomIdProvider.notifier).state = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final actions = ref.read(chatActionsProvider);

    if (_editingMessage != null) {
      if (!actions.canEdit(
        _editingMessage!,
        isGuardianRoom: widget.isGuardian,
      )) {
        _textController.clear();
        setState(() => _editingMessage = null);
        return;
      }
      try {
        await actions.editMessage(
          _editingMessage!.id,
          text,
          isGuardianRoom: widget.isGuardian,
        );
      } catch (e) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Gagal menyimpan pesan: $e');
        }
        return;
      }
      _textController.clear();
      setState(() => _editingMessage = null);
      return;
    }

    try {
      await actions.sendMessage(
        widget.chatId,
        text,
        type: MessageType.text,
        isViewOnce: _isViewOnce,
        replyToId: _replyMessage?.id,
        autoDeleteHours: _autoDeleteHours,
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengirim pesan: $e');
      }
      // Teks TIDAK dihapus dari composer supaya pengguna bisa coba kirim ulang.
      return;
    }

    _textController.clear();
    setState(() {
      _isViewOnce = false;
      _replyMessage = null;
    });

    _scrollToBottom();
  }

  Future<void> _handleSendMedia(File file, MessageType type) async {
    try {
      final uploader = MediaUploadService(Supabase.instance.client);
      
      String? fileKeyB64;
      String url;

      // Cek apakah room mendukung E2EE dengan melakukan uji enkripsi (lawan chat punya public key)
      final tempEnvelope = await E2eeService.instance.encryptForRoom(widget.chatId, 'test-media-e2ee');
      if (tempEnvelope != null) {
        // Kamar chat mendukung E2EE, enkripsi & unggah media
        final result = await uploader.uploadEncryptedChatMedia(file, widget.chatId);
        url = result.url;
        fileKeyB64 = result.keyB64;
      } else {
        // Fallback: unggah plaintext
        url = await uploader.uploadChatMedia(file, widget.chatId);
      }

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            fileKeyB64 ?? '',
            mediaUrl: url,
            type: type,
            autoDeleteHours: _autoDeleteHours,
          );
      _scrollToBottom();
    } catch (e) {
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

  void _toggleViewOnce() {
    setState(() => _isViewOnce = !_isViewOnce);
    MekaarSnackbar.info(
      context,
      _isViewOnce
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
        return Column(
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
                    ? const Icon(Icons.check, color: MekaarColors.softCoral)
                    : null,
                onTap: () => Navigator.pop(ctx, opt.$1),
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
    if (choice != null) {
      _setAutoDeleteHours(choice);
      await ref.read(chatRepositoryProvider).updateRoomDisappearingOverride(widget.chatId, choice);
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
        backgroundColor: MekaarColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(SolarIconsOutline.shieldKeyhole, color: MekaarColors.guardianTeal),
            SizedBox(width: 8),
            Text('Enkripsi Ujung-ke-Ujung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesan dan panggilan dalam chat ini dilindungi dengan enkripsi ujung-ke-ujung (E2EE) menggunakan pasangan kunci asimetris X25519.',
              style: TextStyle(color: MekaarColors.textPrimary, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ Batasan Forward Secrecy:',
              style: TextStyle(color: MekaarColors.warnAmber, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'MEKAAR saat ini tidak menggunakan rotasi kunci otomatis (Forward Secrecy). Jika kunci privat salah satu pihak bocor di masa mendatang, pesan-pesan lama dalam ruang obrolan ini secara teoritis dapat didekripsi. Amankan PIN dan perangkat Anda.',
              style: TextStyle(color: MekaarColors.textSecondary, fontSize: 12),
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
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: widget.chatName,
        avatarInitial: widget.chatAvatar,
        avatarUrl: widget.chatAvatarUrl,
        isGuardian: widget.isGuardian,
        showOnlineIndicator: true,
        isOnline: _isCurrentlyOnline || _partnerIsTyping,
        subtitle: _buildPresenceSubtitle(),
        onAvatarTap: widget.otherUserId != null
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
            : null,
        actions: [
          // E2EE Lock/Secure Indicator
          IconButton(
            icon: const Icon(
              SolarIconsOutline.shieldKeyhole,
              color: MekaarColors.guardianTeal,
            ),
            onPressed: _showE2eeInfoDialog,
            tooltip: 'Informasi Enkripsi',
          ),
          // Voice Call icon
          IconButton(
            icon: const Icon(
              SolarIconsOutline.phone,
              color: MekaarColors.softCoral,
            ),
            onPressed: () => _initiateCall('voice'),
            tooltip: 'Panggilan Suara',
          ),
          // Actions Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(
              SolarIconsOutline.menuDots,
              color: MekaarColors.softCoral,
            ),
            onSelected: (value) async {
              if (value == 'video') {
                _initiateCall('video');
              } else if (value == 'screen_protection') {
                final nextValue = !(protection?.callerEnabled ?? true);
                final ctx = context;
                try {
                  await ref
                      .read(screenProtectionControllerProvider)
                      .setRoomPreference(widget.chatId, nextValue);
                } catch (_) {
                  if (!ctx.mounted) return;
                  MekaarSnackbar.error(
                    ctx,
                    'Pengaturan proteksi belum dapat disinkronkan',
                  );
                }
              } else if (value == 'auto_delete') {
                _showAutoDeleteMenu();
              } else if (value == 'view_once') {
                _toggleViewOnce();
              } else if (value == 'clear') {
                _confirmClearHistory();
              } else if (value == 'delete') {
                _confirmDeleteChat();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'video',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.videocamera,
                      size: 20,
                      color: MekaarColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text('Panggilan Video'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'screen_protection',
                child: Row(
                  children: [
                    const Icon(
                      SolarIconsOutline.shieldCheck,
                      size: 20,
                      color: MekaarColors.safeTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      protection?.callerEnabled == true
                          ? 'Nonaktifkan proteksi layar'
                          : 'Aktifkan proteksi layar',
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'auto_delete',
                child: Row(
                  children: [
                    Icon(
                      _autoDeleteHours > 0
                          ? SolarIconsBold.history
                          : SolarIconsOutline.history,
                      size: 20,
                      color: _autoDeleteHours > 0
                          ? MekaarColors.softCoral
                          : MekaarColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text('Pesan Menghilang: ${_autoDeleteLabel()}'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'view_once',
                child: Row(
                  children: [
                    Icon(
                      _isViewOnce ? SolarIconsBold.eye : SolarIconsOutline.eye,
                      size: 20,
                      color: _isViewOnce
                          ? MekaarColors.softCoral
                          : MekaarColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text('Sekali Lihat: ${_isViewOnce ? 'Aktif' : 'Mati'}'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.trashBinMinimalistic,
                      size: 20,
                      color: MekaarColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text('Bersihkan Riwayat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.trashBinMinimalistic,
                      size: 20,
                      color: MekaarColors.sosRed,
                    ),
                    SizedBox(width: 8),
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
      ),

      body: Stack(
        children: [
          Column(
            children: [
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
                        pose: MikaPose.ask,
                        title: 'Belum Ada Pesan',
                        message: 'Belum ada pesan. Kirim pesan pertama!',
                      );
                    }

                    final reversed = messages.reversed.toList();

                    // Build items with date separators interleaved
                    final itemBuilder = _buildMessageItems(
                      reversed,
                      currentUserId,
                      actions,
                    );

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: itemBuilder.length,
                      itemBuilder: (context, index) => itemBuilder[index],
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
              if (_partnerIsTyping) const TypingIndicator(),
              ChatComposer(
                controller: _textController,
                replyMessage: _replyMessage,
                editingMessage: _editingMessage,
                enabled: isE2eeReady,
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
            ],
          ),
          // Scroll-to-bottom floating button
          Positioned(
            right: 16,
            bottom: 8,
            child: ScrollToBottomButton(
              visible: _showScrollButton,
              newMessageCount: _newMessageCount,
              onTap: () {
                _scrollToBottom();
                setState(() => _newMessageCount = 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build message list items with date separators and entrance animations.
  List<Widget> _buildMessageItems(
    List<Message> messages,
    String? currentUserId,
    ChatActionsNotifier actions,
  ) {
    final items = <Widget>[];
    DateTime? lastDate;

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime(
        msg.createdAt.year,
        msg.createdAt.month,
        msg.createdAt.day,
      );

      // Insert date separator when date changes
      if (lastDate == null || msgDate != lastDate) {
        items.add(
          ChatDateSeparator(date: msg.createdAt),
        );
        lastDate = msgDate;
      }

      final isMe = msg.senderId == currentUserId;
      final canEdit = actions.canEdit(
        msg,
        isGuardianRoom: widget.isGuardian,
      );

      final bubble = ChatBubble(
        message: msg,
        isMe: isMe,
        canDelete: true, // Semua pesan bisa dihapus secara lokal (hide for me)
        canUnsend: isMe, // Hanya pengirim yang bisa tarik pesan (delete for everyone)
        canEdit: isMe && canEdit,
        canForward: actions.canForward(msg),
        otherLastReadAt: _otherLastRead,
        showReadReceipts:
            ref.watch(authProvider).profile?.readReceiptsEnabled ?? true,
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
        onForward: (forwardMsg) => _handleForwardMessage(forwardMsg),
        onReact: (reactMsg, emoji) =>
            _handleReactToMessage(reactMsg, emoji),
      );

      // Wrap with swipe-to-reply gesture
      items.add(
        _SwipeToReplyWrapper(
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

    return items;
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

