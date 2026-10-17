import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/call_state_provider.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String roomId;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String callType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.roomId,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.callType,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  RealtimeChannel? _statusChannel;
  RealtimeChannel? _signalingChannel;
  Timer? _ringingBroadcastTimer;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _watchCallCancelledByCaller();
    _broadcastDeviceRinging();
  }

  /// Memberi tahu pemanggil bahwa perangkat penerima sedang aktif berdering
  void _broadcastDeviceRinging() {
    try {
      final client = ref.read(supabaseServiceProvider).client;
      final myUserId = ref.read(authProvider).user?.id ?? '';
      final channelTopic = 'room_call:${widget.callId}';
      _signalingChannel = client.channel(channelTopic);

      void sendRingingSignal() {
        if (!mounted || _isResponding) return;
        try {
          _signalingChannel?.sendBroadcastMessage(
            event: 'signal',
            payload: {
              'sender': myUserId,
              'signal_type': 'device_ringing',
              'type': 'device_ringing',
              'data': {'callId': widget.callId},
            },
          );
        } catch (_) {}
      }

      _signalingChannel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          sendRingingSignal();
          // Retransmit 1.5 detik kemudian untuk memastikan pemanggil menangkap sinyal
          _ringingBroadcastTimer?.cancel();
          _ringingBroadcastTimer = Timer(const Duration(milliseconds: 1500), sendRingingSignal);
        }
      });
    } catch (_) {}
  }

  /// Memantau jika penelepon membatalkan panggilan sebelum direspons
  void _watchCallCancelledByCaller() {
    final client = ref.read(supabaseServiceProvider).client;
    _statusChannel = client
        .channel('public:calls:status:${widget.callId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.callId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == 'missed' || newStatus == 'ended' || newStatus == 'failed') {
              if (mounted) {
                NotificationService.cancelIncomingCallNotification();
                Navigator.of(context).pop();
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _acceptCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    HapticService.trigger(MekaarHapticIntent.success);

    // Set active call ID in Riverpod so collision guard protects ongoing call
    ref.read(activeCallIdProvider.notifier).state = widget.callId;

    try {
      await ref
          .read(callRepositoryProvider)
          .updateCallStatus(widget.callId, 'answered');
    } catch (e) {
      debugPrint(
        '[CALL_ACCEPT] Peringatan: Gagal memperbarui status DB saat terima panggilan ($e). '
        'Tetap melanjutkan ke CallScreen untuk inisialisasi WebRTC.',
      );
    }
    unawaited(NotificationService.cancelIncomingCallNotification());

    if (!mounted) return;
    final myUserId = ref.read(authProvider).user?.id ?? '';

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.call,
      arguments: {
        'callId': widget.callId,
        'roomId': widget.roomId,
        'chatName': widget.callerName,
        'callerId': widget.callerId,
        'receiverId': myUserId,
        'isCaller': false,
        'callType': widget.callType,
      },
    );
  }

  void _declineCall() {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    HapticService.trigger(MekaarHapticIntent.destructive);

    ref.read(activeCallIdProvider.notifier).state = null;

    // Fire & forget background update
    unawaited(ref.read(callRepositoryProvider).updateCallStatus(widget.callId, 'declined'));
    unawaited(NotificationService.cancelIncomingCallNotification());

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _ringingBroadcastTimer?.cancel();
    _statusChannel?.unsubscribe();
    _signalingChannel?.unsubscribe();
    NotificationService.cancelIncomingCallNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 550;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(height: isCompact ? 12 : 40),
                      // Header Info Panggilan
                      Column(
                        children: [
                          Avatar(
                            initial: widget.callerName.isNotEmpty
                                ? widget.callerName[0].toUpperCase()
                                : 'U',
                            imageUrl: widget.callerAvatarUrl,
                            size: isCompact ? 68 : 110,
                          ),
                          SizedBox(height: isCompact ? 12 : 24),
                          Text(
                            widget.callerName,
                            style: TextStyle(
                              fontSize: isCompact ? 20 : 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVideo
                                    ? SolarIconsOutline.videocamera
                                    : SolarIconsOutline.phone,
                                color: MekaarColors.softCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVideo
                                    ? 'Panggilan Video Masuk...'
                                    : 'Panggilan Suara Masuk...',
                                style: TextStyle(
                                  fontSize: isCompact ? 14 : 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Geser ke atas untuk merespons',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      // Tombol Slide Up Terima / Tolak Panggilan
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isCompact ? 24.0 : 50.0,
                          left: isCompact ? 24.0 : 40.0,
                          right: isCompact ? 24.0 : 40.0,
                          top: 16.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Slider Tolak (Geser ke atas)
                            _SlideUpCallButton(
                              label: 'Tolak',
                              icon: SolarIconsBold.phone,
                              color: MekaarColors.sosRed,
                              onTrigger: _declineCall,
                              disabled: _isResponding,
                            ),

                            // Slider Terima (Geser ke atas)
                            _SlideUpCallButton(
                              label: 'Terima',
                              icon: SolarIconsBold.phone,
                              color: MekaarColors.safeTeal,
                              onTrigger: _acceptCall,
                              disabled: _isResponding,
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
        ),
      ),
    );
  }
}

/// Widget Tombol Slide-Up Interaktif (Geser Ke Atas Untuk Merespons Panggilan)
class _SlideUpCallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTrigger;
  final bool disabled;

  const _SlideUpCallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTrigger,
    required this.disabled,
  });

  @override
  State<_SlideUpCallButton> createState() => _SlideUpCallButtonState();
}

class _SlideUpCallButtonState extends State<_SlideUpCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;
  double _dragOffsetY = 0.0;
  static const double _triggerThreshold = -85.0; // Pemicu 85px geser ke atas
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: MekaarMotion.loop,
    );

    _pulseAnim = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: cincin pulse dimatikan, tombol tetap berfungsi.
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.stop();
      _animController.value = 0;
    } else if (!_animController.isAnimating) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.disabled || _hasTriggered) return;
    setState(() {
      _dragOffsetY += details.delta.dy;
      if (_dragOffsetY > 0) _dragOffsetY = 0; // Hanya izinkan geser ke atas
      if (_dragOffsetY < -110) _dragOffsetY = -110; // Batasi geser maksimum
    });

    if (_dragOffsetY <= _triggerThreshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticService.trigger(MekaarHapticIntent.warning);
      widget.onTrigger();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_hasTriggered) return;
    // Spring back jika belum mencapai ambang batas
    setState(() {
      _dragOffsetY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Panah indikator melayang ke atas dengan animasi
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_pulseAnim.value),
              child: Opacity(
                opacity: (1.0 - (_dragOffsetY.abs() / 100.0)).clamp(0.2, 1.0),
                child: const Icon(
                  SolarIconsOutline.altArrowUp,
                  color: Colors.white60,
                  size: 22,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Handle Tombol yang dapat digeser (didukung Semantics untuk TalkBack/VoiceOver)
        Semantics(
          button: true,
          enabled: !widget.disabled,
          label: widget.label == 'Terima' ? 'Terima panggilan' : 'Tolak panggilan',
          hint: 'Ketuk dua kali atau geser ke atas untuk ${widget.label.toLowerCase()} panggilan',
          onTap: widget.disabled
              ? null
              : () {
                  if (!_hasTriggered) {
                    _hasTriggered = true;
                    HapticService.trigger(MekaarHapticIntent.warning);
                    widget.onTrigger();
                  }
                },
          child: GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: AnimatedContainer(
              duration: MekaarMotion.fast,
              curve: MekaarMotion.standard,
              transform: Matrix4.translationValues(0, _dragOffsetY, 0),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
