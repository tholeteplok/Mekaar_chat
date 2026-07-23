import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';

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

    try {
      await ref.read(callRepositoryProvider).updateCallStatus(widget.callId, 'answered');
    } catch (_) {}

    await NotificationService.cancelIncomingCallNotification();

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

  Future<void> _declineCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    HapticService.trigger(MekaarHapticIntent.destructive);

    try {
      await ref.read(callRepositoryProvider).updateCallStatus(widget.callId, 'declined');
    } catch (_) {}

    await NotificationService.cancelIncomingCallNotification();

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
              ],
            ),

            // Tombol Terima / Tolak Panggilan
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0, left: 36.0, right: 36.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tombol Tolak
                  GestureDetector(
                    onTap: _isResponding ? null : _declineCall,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MekaarColors.sosRed,
                          ),
                          child: const Icon(
                            SolarIconsBold.phone,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tolak',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  // Tombol Terima
                  GestureDetector(
                    onTap: _isResponding ? null : _acceptCall,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MekaarColors.safeTeal,
                          ),
                          child: const Icon(
                            SolarIconsBold.phone,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Terima',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
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
