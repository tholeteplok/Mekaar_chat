import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
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
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _watchCallCancelledByCaller();
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
      ref.read(activeCallIdProvider.notifier).state = null;
      if (mounted) {
        setState(() => _isResponding = false);
        MekaarSnackbar.error(context, 'Gagal menjawab panggilan: $e');
      }
      return;
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
    _statusChannel?.unsubscribe();
    NotificationService.cancelIncomingCallNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 40),
            // Header Info Panggilan
            Column(
              children: [
                Avatar(
                  initial: widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : 'U',
                  imageUrl: widget.callerAvatarUrl,
                  size: 110,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVideo ? SolarIconsOutline.videocamera : SolarIconsOutline.phone,
                      color: MekaarColors.softCoral,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'Panggilan Video Masuk...' : 'Panggilan Suara Masuk...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Geser ke atas untuk merespons',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // Tombol Slide Up Terima / Tolak Panggilan
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0, left: 40.0, right: 40.0),
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
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

        // Handle Tombol yang dapat digeser
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
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
