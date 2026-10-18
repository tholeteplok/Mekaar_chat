import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/webrtc_signaling_service.dart';
import '../../../data/services/wakelock_service.dart';
import '../providers/screen_protection_provider.dart';
import '../providers/call_state_provider.dart';
import '../widgets/call_e2ee_badge.dart';
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
  String _callStatus = 'Menyiapkan...';
  String? _myUserId;
  String? _avatarUrl;
  String? _currentCallId;
  RealtimeChannel? _statusChannel;
  Timer? _callTimeoutTimer;
  Timer? _callingHandshakeTimer;
  Timer? _statusPollingTimer;
  Timer? _durationTimer;
  DateTime? _connectedAt;

  bool get _isConnected =>
      _connectedAt != null ||
      _callStatus == 'Terhubung' ||
      _callStatus == 'Tersambung';

  String get _displayCallStatus {
    if (_connectedAt != null) {
      final seconds = DateTime.now().difference(_connectedAt!).inSeconds;
      final m = (seconds ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return 'Terhubung ($m:$s)';
    }
    return _callStatus;
  }

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
    unawaited(WakelockService.enable());
  }

  void _handleStatusChange(String? newStatus) {
    if (newStatus == null || _isEnding || _isDisposed) return;
    if (newStatus == 'declined') {
      _callingHandshakeTimer?.cancel();
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _durationTimer?.cancel();
      _finishCall('Panggilan ditolak');
    } else if (newStatus == 'busy') {
      _callingHandshakeTimer?.cancel();
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _durationTimer?.cancel();
      _finishCall('Pengguna sedang dalam panggilan lain');
    } else if (newStatus == 'ended') {
      _callingHandshakeTimer?.cancel();
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _durationTimer?.cancel();
      _finishCall('Panggilan berakhir');
    } else if (newStatus == 'missed') {
      _callingHandshakeTimer?.cancel();
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _durationTimer?.cancel();
      _finishCall('Tidak dijawab');
    } else if (newStatus == 'failed') {
      _callingHandshakeTimer?.cancel();
      _callTimeoutTimer?.cancel();
      _statusPollingTimer?.cancel();
      _durationTimer?.cancel();
      _finishCall('Koneksi panggilan gagal');
    } else if (newStatus == 'calling') {
      if (widget.isCaller && mounted && !_isConnected) {
        setState(() {
          _callStatus = 'Memanggil...';
        });
      }
    } else if (newStatus == 'ringing') {
      _callingHandshakeTimer?.cancel();
      if (widget.isCaller && mounted && !_isConnected) {
        setState(() {
          _callStatus = 'Berdering...';
        });
      }
    } else if (newStatus == 'answered') {
      _callingHandshakeTimer?.cancel();
      // Reset timeout: cancel timer lama 30 detik, mulai timer koneksi ICE 25 detik
      // agar ada cukup waktu untuk negosiasi SDP + ICE gathering setelah dijawab.
      _callTimeoutTimer?.cancel();
      _startIceConnectionTimer();
      if (mounted && !_isConnected) {
        setState(() {
          _callStatus = 'Menghubungkan...';
        });
      }
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
    _statusPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      _,
    ) async {
      if (_isEnding || _isDisposed || _isConnected) {
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

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isEnding || _isDisposed || _connectedAt == null) {
        _durationTimer?.cancel();
        return;
      }
      setState(() {});
    });
  }

  /// Timer handshake calling: jika penerima belum mengirimkan sinyal berdering (ACK)
  /// dalam 15 detik, akhiri panggilan dengan status 'Penerima tidak dapat dihubungi'.
  void _startCallingHandshakeTimer() {
    _callingHandshakeTimer?.cancel();
    if (!widget.isCaller) return;
    _callingHandshakeTimer = Timer(const Duration(seconds: 15), () async {
      if (!_isConnected && !_isEnding && !_isDisposed && _callStatus == 'Memanggil...') {
        if (_currentCallId != null) {
          try {
            await ref
                .read(callRepositoryProvider)
                .updateCallStatus(_currentCallId!, 'missed');
          } catch (_) {}
        }
        _finishCall('Penerima tidak dapat dihubungi');
      }
    });
  }

  void _startCallTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      if (!_isConnected && !_isEnding && !_isDisposed) {
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
    if (widget.isCaller) {
      _startCallingHandshakeTimer();
    }
  }

  /// Timer koneksi ICE — dimulai setelah panggilan dijawab.
  /// Memberi 25 detik tambahan untuk negosiasi SDP + ICE gathering + TURN relay.
  void _startIceConnectionTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 25), () async {
      if (!_isConnected && !_isEnding && !_isDisposed) {
        if (_currentCallId != null) {
          try {
            await ref
                .read(callRepositoryProvider)
                .updateCallStatus(_currentCallId!, 'failed');
          } catch (_) {}
        }
        _finishCall('Koneksi panggilan gagal');
      }
    });
  }

  Future<void> _loadAvatar() async {
    final otherId = widget.isCaller ? widget.receiverId : widget.callerId;
    try {
      final profileRow = await ref
          .read(supabaseServiceProvider)
          .client
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
      if (mounted) {
        setState(() {
          _callStatus = 'Menyiapkan...';
          _statusIsError = false;
        });
      }

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

      // Cek & minta izin mikrofon (dan kamera untuk video call) sebelum initMedia
      final hasPermission = await _requestCallPermissions();
      if (!hasPermission) {
        _finishCall('Izin mikrofon diperlukan untuk panggilan');
        return;
      }
      if (_isDisposed || _isEnding) {
        _cleanUp();
        return;
      }

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
          _callStatus = widget.isCaller ? 'Memanggil...' : 'Menghubungkan...';
          _statusIsError = false;
        });
      }

      if (widget.isCaller && _currentCallId == null) {
        try {
          final callRow = await ref
              .read(callRepositoryProvider)
              .createCall(
                roomId: widget.roomId,
                callerId: widget.callerId,
                receiverId: widget.receiverId,
                callType: widget.callType,
              );
          _currentCallId = callRow['id'] as String?;
          if (_currentCallId != null && mounted) {
            ref.read(activeCallIdProvider.notifier).state = _currentCallId!;
          }
        } catch (e, st) {
          debugPrint('[CallScreen] createCall error: $e\n$st');
          _finishCall('Gagal terhubung ke panggilan');
          return;
        }
      }

      if (_currentCallId != null) {
        _watchCallStatus();
      }
      _startCallTimeoutTimer();

      await signaling.startSignaling(
        roomId: widget.roomId,
        callId: _currentCallId ?? widget.roomId,
        myUserId: userId,
        isCaller: widget.isCaller,
        isVideo: _isVideoCall,
      );

      if (mounted && !_isConnected) {
        setState(() {
          _callStatus = widget.isCaller ? 'Memanggil...' : 'Menghubungkan...';
        });
      }

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

  /// Minta izin mikrofon (dan kamera untuk video call).
  /// Menampilkan SnackBar informatif jika izin ditolak, dengan opsi buka Settings.
  Future<bool> _requestCallPermissions() async {
    // Cek mikrofon
    final hasMic = await PermissionsHelper.hasMicPermission();
    if (!hasMic) {
      final granted = await PermissionsHelper.requestMic();
      if (!granted) {
        if (mounted) {
          final isPermanent = await PermissionsHelper.isMicPermanentlyDenied();
          if (mounted) {
            if (isPermanent) {
              MekaarSnackbar.error(
                context,
                'Izin mikrofon diblokir. Buka Pengaturan > Izin Aplikasi untuk mengaktifkan.',
              );
              // Otomatis buka settings jika sudah permanently denied
              PermissionsHelper.openSettings();
            } else {
              MekaarSnackbar.error(
                context,
                'Izin mikrofon diperlukan untuk melakukan panggilan.',
              );
            }
          }
        }
        return false;
      }
    }

    // Cek kamera untuk video call
    if (_isVideoCall) {
      final hasCam = await PermissionsHelper.hasCameraPermission();
      if (!hasCam) {
        final granted = await PermissionsHelper.requestCamera();
        if (!granted) {
          if (mounted) {
            MekaarSnackbar.warning(
              context,
              'Izin kamera ditolak. Panggilan dilanjutkan tanpa video.',
            );
          }
          // Tetap lanjutkan panggilan tanpa video
          _isVideoOn = false;
        }
      }
    }

    return true;
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
      if (normalizedState == 'ringing') {
        _callingHandshakeTimer?.cancel();
      } else if (normalizedState == 'connected') {
        _callingHandshakeTimer?.cancel();
        _connectedAt ??= DateTime.now();
        _callTimeoutTimer?.cancel();
        _startDurationTimer();
        if (_currentCallId != null && !widget.isCaller) {
          unawaited(
            ref
                .read(callRepositoryProvider)
                .updateCallStatus(
                  _currentCallId!,
                  'answered',
                  startedAt: _connectedAt,
                )
                .catchError((e) {
                  debugPrint('[CALL_CONNECT] Peringatan update call: $e');
                }),
          );
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
      case 'preparing':
        return 'Menyiapkan...';
      case 'connecting':
        return 'Menghubungkan...';
      case 'calling':
        return 'Memanggil...';
      case 'ringing':
        return 'Berdering...';
      case 'connected':
        return 'Terhubung';
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

  Future<void> _switchCamera() async {
    if (!_mediaReady || _isEnding || !_isVideoCall) return;
    final videoTracks = _signaling?.localStream?.getVideoTracks() ?? [];
    if (videoTracks.isEmpty) return;
    try {
      await Helper.switchCamera(videoTracks.first);
      if (mounted) {
        HapticService.trigger(MekaarHapticIntent.selection);
      }
    } catch (e) {
      debugPrint('[CallScreen] Gagal membalikkan kamera: $e');
    }
  }

  void _onCameraButtonTapped() {
    if (!_mediaReady || _isEnding) return;
    if (_isVideoCall) {
      _toggleVideo();
    } else {
      HapticService.trigger(MekaarHapticIntent.selection);
      MekaarSnackbar.info(
        context,
        'Panggilan ini adalah panggilan suara. Untuk berbagi kamera, mulai panggilan video.',
      );
    }
  }

  Future<void> _hangup() async {
    if (_isEnding) {
      return;
    }
    _isEnding = true;
    _callingHandshakeTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _durationTimer?.cancel();
    if (_currentCallId != null) {
      try {
        if (_connectedAt != null) {
          await ref
              .read(callRepositoryProvider)
              .endCall(_currentCallId!, startedAt: _connectedAt);
        } else {
          final endStatus = _isConnected ? 'ended' : 'missed';
          await ref
              .read(callRepositoryProvider)
              .updateCallStatus(_currentCallId!, endStatus);
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
    _callingHandshakeTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _durationTimer?.cancel();
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
    _callingHandshakeTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _statusPollingTimer?.cancel();
    _durationTimer?.cancel();
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
    unawaited(WakelockService.disable());
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
            // 1. Lapisan Background (Stream video penuh atau Background Blur Dinamis)
            if (_isVideoCall && _remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Positioned.fill(
                child: _buildCallBackground(),
              ),

            // Gradient overlay halus jika video aktif
            if (_isVideoCall && _remoteRenderer.srcObject != null)
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

            // 2. Bar Atas: E2EE Emoji Badge & Screen Protection Badge
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CallE2eeBadge(
                      callId: _currentCallId ?? widget.roomId,
                      myUserId: _myUserId ?? '',
                      remoteUserId: widget.isCaller
                          ? widget.receiverId
                          : widget.callerId,
                      chatName: widget.chatName,
                    ),
                    if (protection?.effective ?? true)
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ScreenProtectionStatusBadge(
                            label: protection?.statusLabel ?? 'Proteksi aktif',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 3. Konten Utama: Avatar, Status, Nama (Hanya tampil jika bukan video penuh)
            if (!_isVideoCall || _remoteRenderer.srcObject == null)
              Positioned(
                top: 110,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Avatar(
                        initial: widget.chatName.isNotEmpty
                            ? widget.chatName[0].toUpperCase()
                            : 'U',
                        imageUrl: _avatarUrl,
                        size: 110,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_statusIsError) ...[
                          const Icon(
                            MekaarIcons.errorOutline,
                            color: MekaarColors.sosRed,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            _displayCallStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: _statusIsError
                                  ? MekaarColors.sosRed
                                  : Colors.white70,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.chatName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Video PiP & Flip Camera
            if (_isVideoCall && _isVideoOn && _localRenderer.srcObject != null) ...[
              Positioned(
                top: 75,
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
                top: 75,
                left: 20,
                child: SafeArea(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _switchCamera,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            MekaarIcons.cameraRotate,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Output Audio (Speaker / Earpiece)
                      _controlButton(
                        icon: _isSpeakerOn
                            ? MekaarIcons.speakerOn
                            : MekaarIcons.speakerOff,
                        label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                        isActive: _isSpeakerOn,
                        onTap: _mediaReady && !_isEnding ? _toggleSpeaker : null,
                        tooltip: _isSpeakerOn
                            ? 'Beralih ke Earpiece'
                            : 'Nyalakan Speaker',
                      ),
                      // 2. Kamera
                      _controlButton(
                        icon: (_isVideoCall && !_isVideoOn)
                            ? MekaarIcons.videocamOff
                            : MekaarIcons.videocam,
                        label: _isVideoCall
                            ? (_isVideoOn ? 'Kamera' : 'Kamera Mati')
                            : 'Kamera',
                        isActive: _isVideoCall && _isVideoOn,
                        isAlert: _isVideoCall && !_isVideoOn,
                        onTap: _mediaReady && !_isEnding ? _onCameraButtonTapped : null,
                        tooltip: _isVideoCall
                            ? (_isVideoOn ? 'Matikan Kamera' : 'Nyalakan Kamera')
                            : 'Kamera Tidak Tersedia',
                      ),
                      // 3. Mikrofon
                      _controlButton(
                        icon: _isMuted ? MekaarIcons.micOff : MekaarIcons.mic,
                        label: _isMuted ? 'Bisu' : 'Mikrofon',
                        isAlert: _isMuted,
                        onTap: _mediaReady && !_isEnding ? _toggleMute : null,
                        tooltip: _isMuted ? 'Nyalakan Mikrofon' : 'Bisukan Mikrofon',
                      ),
                      // 4. Akhiri Panggilan
                      _controlButton(
                        icon: MekaarIcons.callEnd,
                        label: 'Akhiri',
                        backgroundColor: MekaarColors.sosRed,
                        iconColor: Colors.white,
                        onTap: _isEnding ? null : _hangup,
                        tooltip: 'Akhiri Panggilan',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menghasilkan latar belakang dinamis dengan Gaussian blur tinggi pada avatar kontak
  /// dan ambient dark vignette overlay sesuai estetika referensi modern.
  Widget _buildCallBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ambient gradient dasar yang elegan (slate-800 ke deep dark)
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.3,
              colors: [
                Color(0xFF1E293B), // slate-800
                Color(0xFF0F172A), // slate-900
                Color(0xFF050811), // deep slate dark
              ],
            ),
          ),
        ),

        // 2. Avatar blur jika gambar tersedia
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Transform.scale(
                scale: 1.25,
                child: Image.network(
                  _avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // 3. Vignette gelap bertingkat untuk keterbacaan tipografi optimal
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
    bool isAlert = false,
    Color? backgroundColor,
    Color? iconColor,
    String? tooltip,
    double size = 52,
  }) {
    final effectiveBgColor = backgroundColor ??
        (isAlert
            ? Colors.white
            : isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18));
    final effectiveIconColor = iconColor ??
        (isAlert
            ? MekaarColors.sosRed
            : isActive
                ? Colors.black87
                : Colors.white);

    return Semantics(
      label: tooltip ?? label,
      button: true,
      enabled: onTap != null,
      child: Tooltip(
        message: tooltip ?? label,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: effectiveBgColor,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: effectiveIconColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isAlert ? MekaarColors.sosRed : Colors.white70,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
