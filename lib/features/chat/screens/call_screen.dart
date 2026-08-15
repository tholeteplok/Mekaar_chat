import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/webrtc_signaling_service.dart';
import '../providers/screen_protection_provider.dart';
import '../providers/call_state_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/constants/icons.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String? callId;
  final String roomId;
  final String chatName;
  final String callerId;
  final String receiverId;
  final bool isCaller;
  final String callType;

  const CallScreen({
    super.key,
    this.callId,
    required this.roomId,
    required this.chatName,
    required this.callerId,
    required this.receiverId,
    required this.isCaller,
    required this.callType,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with WidgetsBindingObserver {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  WebRtcSignalingService? _signaling;
  bool _localRendererInitialized = false;
  bool _remoteRendererInitialized = false;
  bool _mediaReady = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = false;
  bool _isEnding = false;
  bool _isCleanedUp = false;
  bool _isDisposed = false;
  bool _allowPop = false;
  bool _hasPopped = false;
  bool _statusIsError = false;
  String _callStatus = 'Menyiapkan panggilan...';
  String? _myUserId;
  String? _avatarUrl;
  String? _currentCallId;
  RealtimeChannel? _statusChannel;
  Timer? _callTimeoutTimer;
  Timer? _statusPollingTimer;
  DateTime? _connectedAt;

  bool get _isVideoCall => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myUserId = ref.read(authProvider).user?.id;
    _currentCallId = widget.callId;
    _isVideoOn = _isVideoCall;
    _isSpeakerOn = _isVideoCall;

    // Register active call ID in Riverpod
    final initialId = _currentCallId ?? widget.roomId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeCallIdProvider.notifier).state = initialId;
      }
    });

    _loadAvatar();
    _initializeCall();
  }

  void _handleStatusChange(String? newStatus) {
    if (newStatus == null || _isEnding || _isDisposed) return;
    if (newStatus == 'declined') {
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _finishCall('Panggilan ditolak');
    } else if (newStatus == 'busy') {
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _finishCall('Pengguna sedang dalam panggilan lain');
    } else if (newStatus == 'ended') {
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _finishCall('Panggilan berakhir');
    } else if (newStatus == 'missed') {
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _finishCall('Tidak dijawab');
    } else if (newStatus == 'failed') {
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _finishCall('Koneksi panggilan gagal');
    } else if (newStatus == 'answered') {
      _callTimeoutTimer?.cancel();
      if (widget.isCaller && _myUserId != null) {
        _signaling?.createOfferIfPending(_myUserId!);
      }
    }
  }

  void _watchCallStatus() {
    final callId = _currentCallId;
    if (callId == null) return;
    final client = ref.read(supabaseServiceProvider).client;

    // 1. Realtime Postgres Changes
    _statusChannel = client
        .channel('public:calls:watch:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            _handleStatusChange(newStatus);
          },
        )
        .subscribe();

    // 2. Periodic Polling Fallback (1.5 Detik) - Menjamin status pasti ter-update walau WebSocket missed
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_isEnding || _isDisposed || _callStatus == 'Tersambung') {
        _statusPollingTimer?.cancel();
        return;
      }
      try {
        final callData = await ref.read(callRepositoryProvider).getCall(callId);
        if (callData != null) {
          final status = callData['status'] as String?;
          _handleStatusChange(status);
        }
      } catch (_) {}
    });
  }

  void _startCallTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      if (_callStatus != 'Tersambung' && !_isEnding && !_isDisposed) {
        if (_currentCallId != null) {
          try {
            await ref
                .read(callRepositoryProvider)
                .updateCallStatus(_currentCallId!, 'missed');
          } catch (_) {}
        }
        _finishCall('Tidak dijawab');
      }
    });
  }

  Future<void> _loadAvatar() async {
    final otherId = widget.isCaller ? widget.receiverId : widget.callerId;
    try {
      final profileRow = await ref.read(supabaseServiceProvider).client
          .from('public_profiles')
          .select('avatar_url')
          .eq('id', otherId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _avatarUrl = profileRow?['avatar_url'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeCall() async {
    try {
      if (widget.isCaller && _currentCallId == null) {
        try {
          final callRow = await ref.read(callRepositoryProvider).createCall(
                roomId: widget.roomId,
                callerId: widget.callerId,
                receiverId: widget.receiverId,
                callType: widget.callType,
              );
          _currentCallId = callRow['id'] as String?;
          if (_currentCallId != null && mounted) {
            ref.read(activeCallIdProvider.notifier).state = _currentCallId!;
          }
        } catch (e) {
          _finishCall('Gagal terhubung ke panggilan');
          return;
        }
      }

      if (_currentCallId != null) {
        _watchCallStatus();
      }
      _startCallTimeoutTimer();

      await _localRenderer.initialize();
      _localRendererInitialized = true;
      if (_isDisposed) {
        _localRenderer.dispose();
        _localRendererInitialized = false;
        return;
      }

      await _remoteRenderer.initialize();
      _remoteRendererInitialized = true;
      if (_isDisposed) {
        _remoteRenderer.dispose();
        _remoteRendererInitialized = false;
        return;
      }

      final userId = _myUserId;
      if (userId == null || userId.isEmpty) {
        throw StateError('Pengguna tidak tersedia');
      }

      final signaling = WebRtcSignalingService(Supabase.instance.client);
      _signaling = signaling;
      _configureSignaling(signaling);

      await signaling.initMedia(_isVideoCall);
      if (_isDisposed || _isEnding) {
        _cleanUp();
        return;
      }

      await _selectAudioOutput(_isVideoCall ? 'speaker' : 'earpiece');
      if (_isDisposed || _isEnding) {
        _cleanUp();
        return;
      }

      if (mounted) {
        setState(() {
          _mediaReady = true;
          _callStatus = 'Menghubungkan...';
          _statusIsError = false;
        });
      }

      await signaling.startSignaling(
        roomId: widget.roomId,
        callId: _currentCallId ?? widget.roomId,
        myUserId: userId,
        isCaller: widget.isCaller,
        isVideo: _isVideoCall,
      );
      if (_isDisposed || _isEnding) {
        _cleanUp();
      }
    } catch (_) {
      if (_isDisposed || _isEnding) {
        _cleanUp();
        return;
      }
      _cleanUp();
      if (mounted) {
        setState(() {
          _mediaReady = false;
          _statusIsError = true;
          _callStatus = 'Panggilan gagal disiapkan';
        });
      }
    }
  }

  void _configureSignaling(WebRtcSignalingService signaling) {
    signaling.onLocalStream = (stream) {
      if (!mounted || _isDisposed || !_localRendererInitialized) {
        return;
      }
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    signaling.onRemoteStream = (stream) {
      if (!mounted || _isDisposed || !_remoteRendererInitialized) {
        return;
      }
      if (stream.getAudioTracks().isEmpty && stream.getVideoTracks().isEmpty) {
        return;
      }
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };

    signaling.onCallStateChange = (state) {
      if (!mounted || _isDisposed || _isEnding) {
        return;
      }
      final isDisconnected = const {
        'disconnected',
        'failed',
        'closed',
      }.contains(state.toLowerCase());
      setState(() {
        _callStatus = _localizedCallState(state);
        _statusIsError = isDisconnected;
        if (isDisconnected) {
          _mediaReady = false;
        }
      });
      final normalizedState = state.toLowerCase();
      if (normalizedState == 'connected') {
        _connectedAt ??= DateTime.now();
        _callTimeoutTimer?.cancel();
        if (_currentCallId != null) {
          try {
            ref.read(callRepositoryProvider).updateCallStatus(
                  _currentCallId!,
                  'answered',
                  startedAt: _connectedAt,
                );
          } catch (_) {}
        }
        NotificationService.cancelIncomingCallNotification();
        HapticService.trigger(MekaarHapticIntent.success);
      } else if (isDisconnected) {
        NotificationService.cancelIncomingCallNotification();
        HapticService.trigger(MekaarHapticIntent.warning);
      }
    };

    signaling.onHangup = () {
      _finishCall('Panggilan berakhir');
    };

    signaling.onError = (error) {
      if (!mounted || _isDisposed || _isEnding) {
        return;
      }
      final message = error.toString().toLowerCase();
      final isFatal =
          message.contains('subscribe') ||
          message.contains('ice') ||
          message.contains('gagal');
      if (mounted && !_isDisposed) {
        setState(() {
          _mediaReady = false;
          _statusIsError = true;
          _callStatus = 'Panggilan gagal';
        });
      }
      if (isFatal) {
        _finishCall('Panggilan gagal');
      }
    };
  }

  Future<void> _selectAudioOutput(String output) async {
    try {
      await Helper.selectAudioOutput(output);
    } catch (_) {}
  }

  String _localizedCallState(String state) {
    switch (state.toLowerCase()) {
      case 'calling':
        return 'Memanggil...';
      case 'ringing':
        return 'Berdering...';
      case 'connected':
        return 'Tersambung';
      case 'disconnected':
      case 'failed':
      case 'closed':
        return 'Koneksi terputus';
      case 'ended':
        return 'Panggilan berakhir';
      default:
        return state.isEmpty ? 'Menghubungkan...' : state;
    }
  }

  void _toggleMute() {
    if (!_mediaReady || _isEnding) {
      return;
    }
    final audioTracks = _signaling?.localStream?.getAudioTracks() ?? [];
    if (audioTracks.isEmpty) {
      return;
    }
    final enabled = !audioTracks.first.enabled;
    for (final track in audioTracks) {
      track.enabled = enabled;
    }
    if (mounted) {
      setState(() => _isMuted = !enabled);
      HapticService.trigger(MekaarHapticIntent.selection);
    }
  }

  Future<void> _toggleSpeaker() async {
    if (!_mediaReady || _isEnding) {
      return;
    }
    final speakerOn = !_isSpeakerOn;
    try {
      await Helper.selectAudioOutput(speakerOn ? 'speaker' : 'earpiece');
    } catch (_) {
      return;
    }
    if (mounted && !_isEnding) {
      setState(() => _isSpeakerOn = speakerOn);
      HapticService.trigger(MekaarHapticIntent.selection);
    }
  }

  void _toggleVideo() {
    if (!_mediaReady || _isEnding || !_isVideoCall) {
      return;
    }
    final videoTracks = _signaling?.localStream?.getVideoTracks() ?? [];
    if (videoTracks.isEmpty) {
      return;
    }
    final enabled = !videoTracks.first.enabled;
    for (final track in videoTracks) {
      track.enabled = enabled;
    }
    if (mounted) {
      setState(() => _isVideoOn = enabled);
      HapticService.trigger(MekaarHapticIntent.selection);
    }
  }

  Future<void> _hangup() async {
    if (_isEnding) {
      return;
    }
    _isEnding = true;
    _callTimeoutTimer?.cancel();
    if (_currentCallId != null) {
      try {
        if (_connectedAt != null) {
          await ref.read(callRepositoryProvider).endCall(
                _currentCallId!,
                startedAt: _connectedAt,
              );
        } else {
          final endStatus = _callStatus == 'Tersambung' ? 'ended' : 'missed';
          await ref.read(callRepositoryProvider).updateCallStatus(_currentCallId!, endStatus);
        }
      } catch (_) {}
    }
    NotificationService.cancelIncomingCallNotification();
    HapticService.trigger(MekaarHapticIntent.destructive);
    if (mounted) {
      setState(() {
        _mediaReady = false;
        _statusIsError = false;
        _callStatus = 'Mengakhiri panggilan...';
      });
    }

    final signaling = _signaling;
    final userId = _myUserId;
    if (signaling != null && userId != null && userId.isNotEmpty) {
      signaling.onHangup = null;
      try {
        await signaling.hangup(userId);
      } catch (_) {
        _cleanUp();
      }
    } else {
      _cleanUp();
    }
    _popOnce();
  }

  void _finishCall(String status) {
    if (_isEnding || _isDisposed) {
      return;
    }
    _isEnding = true;
    _callTimeoutTimer?.cancel();
    _cleanUp();
    if (mounted) {
      setState(() {
        _mediaReady = false;
        _statusIsError = false;
        _callStatus = status;
      });
    }
    _popOnce();
  }

  void _popOnce() {
    if (_hasPopped || !mounted) {
      return;
    }
    _hasPopped = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _cleanUp() async {
    if (_isCleanedUp) {
      return;
    }
    _isCleanedUp = true;
    _callTimeoutTimer?.cancel();
    _statusPollingTimer?.cancel();
    _statusChannel?.unsubscribe();

    // Reset activeCallIdProvider in Riverpod
    try {
      ref.read(activeCallIdProvider.notifier).state = null;
    } catch (_) {}

    NotificationService.cancelIncomingCallNotification();
    final signaling = _signaling;
    if (signaling != null) {
      signaling.onLocalStream = null;
      signaling.onRemoteStream = null;
      signaling.onCallStateChange = null;
      signaling.onHangup = null;
      await signaling.cleanUp();
    }
    if (_localRendererInitialized) {
      _localRenderer.srcObject = null;
    }
    if (_remoteRendererInitialized) {
      _remoteRenderer.srcObject = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    final localStream = _localRenderer.srcObject;
    if (localStream == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pause local video tracks when app is backgrounded to conserve bandwidth and privacy
        for (final track in localStream.getVideoTracks()) {
          track.enabled = false;
        }
        break;
      case AppLifecycleState.resumed:
        // Restore local video tracks when app returns to foreground if video was enabled
        if (_isVideoOn) {
          for (final track in localStream.getVideoTracks()) {
            track.enabled = true;
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _cleanUp();
    if (_localRendererInitialized) {
      _localRenderer.dispose();
      _localRendererInitialized = false;
    }
    if (_remoteRendererInitialized) {
      _remoteRenderer.dispose();
      _remoteRendererInitialized = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protection = ref
        .watch(roomScreenProtectionProvider(widget.roomId))
        .valueOrNull;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _hangup();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (protection?.effective ?? true)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: ScreenProtectionStatusBadge(
                    label: protection?.statusLabel ?? 'Proteksi ruang aktif',
                  ),
                ),
              ),
            if (_isVideoCall && _remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            if (_isVideoCall)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (!_isVideoCall) ...[
                    Avatar(
                      initial: widget.chatName.isNotEmpty ? widget.chatName[0].toUpperCase() : 'U',
                      imageUrl: _avatarUrl,
                      size: 100,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_statusIsError) ...[
                        const Icon(
                          MekaarIcons.errorOutline,
                          color: MekaarColors.sosRed,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          _callStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: _statusIsError
                                ? MekaarColors.sosRed
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isVideoCall && _isVideoOn && _localRenderer.srcObject != null)
              Positioned(
                top: 50,
                right: 20,
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _isSpeakerOn ? MekaarIcons.volumeUp : MekaarIcons.volumeDown,
                    color: _isSpeakerOn ? Colors.white : Colors.white24,
                    iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                    onTap: _mediaReady && !_isEnding ? _toggleSpeaker : null,
                    tooltip: _isSpeakerOn ? 'Matikan Speaker' : 'Nyalakan Speaker',
                  ),
                  if (_isVideoCall)
                    _controlButton(
                      icon: _isVideoOn ? MekaarIcons.videocam : MekaarIcons.videocamOff,
                      color: _isVideoOn ? Colors.white : Colors.white24,
                      iconColor: _isVideoOn ? Colors.black : Colors.white,
                      onTap: _mediaReady && !_isEnding ? _toggleVideo : null,
                      tooltip: _isVideoOn ? 'Matikan Kamera' : 'Nyalakan Kamera',
                    ),
                  _controlButton(
                    icon: _isMuted ? MekaarIcons.micOff : MekaarIcons.mic,
                    color: _isMuted ? Colors.white : Colors.white24,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onTap: _mediaReady && !_isEnding ? _toggleMute : null,
                    tooltip: _isMuted ? 'Nyalakan Mikrofon' : 'Mute Mikrofon',
                  ),
                  _controlButton(
                    icon: MekaarIcons.callEnd,
                    color: MekaarColors.sosRed,
                    iconColor: Colors.white,
                    onTap: _isEnding ? null : _hangup,
                    tooltip: 'Akhiri Panggilan',
                    size: 64,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback? onTap,
    String? tooltip,
    double size = 52,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      enabled: onTap != null,
      child: Tooltip(
        message: tooltip ?? '',
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(
                  child: Icon(icon, color: iconColor, size: size * 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
