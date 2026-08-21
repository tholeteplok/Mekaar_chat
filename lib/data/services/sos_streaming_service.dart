import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/webrtc_config.dart';

/// Status koneksi SOS live stream.
enum SosStreamState {
  idle,
  initializing,
  waitingForViewer,
  connecting,
  streaming,
  ended,
  error,
}

/// Service WebRTC Signaling khusus untuk SOS Live Streaming (Korban → Guardian).
///
/// Menggunakan kanal private `sos_stream:<sessionId>` dengan otorisasi RLS
/// Supabase Realtime (migrasi 74).
///
/// Peran:
/// - **Broadcaster (Korban)**: Menginisialisasi kamera/mic lokal, mengirim stream ke Guardian.
/// - **Viewer (Guardian)**: Menghubungkan ke stream dan menerima umpan video & audio real-time.
class SosStreamingService {
  final SupabaseClient _client;
  final Map<String, dynamic> _configuration;
  static final Logger _logger = Logger();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RealtimeChannel? _channel;

  final List<RTCIceCandidate> _pendingCandidates = [];
  final List<Map<String, dynamic>> _myLocalCandidates = [];

  bool _isBroadcaster = false;
  bool _remoteDescriptionSet = false;
  bool _hasCreatedOffer = false;
  bool _hasReceivedAnswer = false;
  bool _isCleaningUp = false;
  bool _isCleanedUp = false;

  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 6;
  static const Duration _retryInterval = Duration(milliseconds: 1500);

  // ── Callbacks ──
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(SosStreamState state)? onStreamStateChange;
  Function()? onViewerJoined;
  Function()? onViewerLeft;
  Function(Object error)? onError;

  SosStreamingService(this._client, {Map<String, dynamic>? configuration})
      : _configuration = configuration ?? WebRtcConfig.buildIceConfiguration();

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isBroadcaster => _isBroadcaster;

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Inisialisasi Media Lokal (Broadcaster / Korban)
  // ──────────────────────────────────────────────────────────────────────────

  Future<MediaStream?> initLocalMedia({
    bool audio = true,
    bool video = true,
    bool isFrontCamera = true,
  }) async {
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': audio
            ? {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              }
            : false,
        'video': video
            ? {
                'mandatory': {
                  'minWidth': '480',
                  'minHeight': '640',
                  'minFrameRate': '15',
                },
                'facingMode': isFrontCamera ? 'user' : 'environment',
                'optional': [],
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);
      return _localStream;
    } catch (e, st) {
      _logger.e('SosStreamingService.initLocalMedia error: $e\n$st');
      onError?.call(e);
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Mulai Broadcast (Sisi Korban)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> startBroadcast({
    required String sessionId,
    required String myUserId,
  }) async {
    _isBroadcaster = true;
    _isCleanedUp = false;
    _isCleaningUp = false;
    _remoteDescriptionSet = false;
    _hasCreatedOffer = false;
    _hasReceivedAnswer = false;
    _pendingCandidates.clear();
    _myLocalCandidates.clear();

    onStreamStateChange?.call(SosStreamState.initializing);

    try {
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners(sessionId, myUserId);

      // Tambahkan track media lokal ke peer connection
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Kanal private sos_stream:<sessionId>
      final channelTopic = 'sos_stream:$sessionId';
      _channel = _client.channel(
        channelTopic,
        opts: const RealtimeChannelConfig(private: true),
      );

      _channel!.onBroadcast(
        event: 'sos_signal',
        callback: (payload) => _handleSignal(payload, myUserId),
      );

      _channel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _logger.i('SosStreaming: Broadcaster terhubung ke $channelTopic');
          onStreamStateChange?.call(SosStreamState.waitingForViewer);

          // Beritahu bahwa korban siap broadcast
          _broadcastSignal(sessionId, myUserId, 'victim_ready', {});
        } else if (status == RealtimeSubscribeStatus.channelError) {
          _logger.e('SosStreaming: Gagal subscribe kanal: $error');
          onError?.call(error ?? 'Kanal SOS stream error');
        }
      });
    } catch (e, st) {
      _logger.e('SosStreamingService.startBroadcast error: $e\n$st');
      onError?.call(e);
      onStreamStateChange?.call(SosStreamState.error);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Bergabung ke Stream (Sisi Guardian)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> joinStream({
    required String sessionId,
    required String myUserId,
  }) async {
    _isBroadcaster = false;
    _isCleanedUp = false;
    _isCleaningUp = false;
    _remoteDescriptionSet = false;
    _hasCreatedOffer = false;
    _hasReceivedAnswer = false;
    _pendingCandidates.clear();
    _myLocalCandidates.clear();

    onStreamStateChange?.call(SosStreamState.connecting);

    try {
      _peerConnection = await createPeerConnection(_configuration);
      _setupPeerConnectionListeners(sessionId, myUserId);

      final channelTopic = 'sos_stream:$sessionId';
      _channel = _client.channel(
        channelTopic,
        opts: const RealtimeChannelConfig(private: true),
      );

      _channel!.onBroadcast(
        event: 'sos_signal',
        callback: (payload) => _handleSignal(payload, myUserId),
      );

      _channel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _logger.i('SosStreaming: Guardian terhubung ke $channelTopic');

          // Kirim sinyal guardian_joined dengan retry
          _startHandshakeRetry(sessionId, myUserId, 'guardian_joined', {});
        } else if (status == RealtimeSubscribeStatus.channelError) {
          _logger.e('SosStreaming: Gagal subscribe kanal: $error');
          onError?.call(error ?? 'Kanal SOS stream error');
        }
      });
    } catch (e, st) {
      _logger.e('SosStreamingService.joinStream error: $e\n$st');
      onError?.call(e);
      onStreamStateChange?.call(SosStreamState.error);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Manajemen Sinyal & Negosiasi SDP
  // ──────────────────────────────────────────────────────────────────────────

  void _setupPeerConnectionListeners(String sessionId, String myUserId) {
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        final candidateMap = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };
        _myLocalCandidates.add(candidateMap);
        _broadcastSignal(sessionId, myUserId, 'candidate', candidateMap);
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
        onStreamStateChange?.call(SosStreamState.streaming);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      _logger.i('SosStreaming ConnectionState: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onStreamStateChange?.call(SosStreamState.streaming);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onStreamStateChange?.call(SosStreamState.ended);
      }
    };
  }

  void _handleSignal(Map<String, dynamic> payload, String myUserId) async {
    final senderId = payload['sender_id'] as String?;
    if (senderId == myUserId) return; // Abaikan pesan sendiri

    final type = payload['type'] as String?;
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final sessionId = payload['session_id'] as String? ?? '';

    _logger.i('SosStreaming received signal: $type from $senderId');

    try {
      switch (type) {
        case 'victim_ready':
          if (!_isBroadcaster) {
            _startHandshakeRetry(sessionId, myUserId, 'guardian_joined', {});
          }
          break;

        case 'guardian_joined':
          if (_isBroadcaster) {
            onViewerJoined?.call();
            await _createAndSendOffer(sessionId, myUserId);
          }
          break;

        case 'offer':
          if (!_isBroadcaster) {
            _retryTimer?.cancel();
            final sdp = data['sdp'] as String?;
            if (sdp != null) {
              final description = RTCSessionDescription(sdp, 'offer');
              await _peerConnection!.setRemoteDescription(description);
              _remoteDescriptionSet = true;
              await _flushPendingCandidates();

              // Buat dan kirim answer
              final answer = await _peerConnection!.createAnswer();
              await _peerConnection!.setLocalDescription(answer);
              _broadcastSignal(sessionId, myUserId, 'answer', {'sdp': answer.sdp});
              _retransmitLocalCandidates(sessionId, myUserId);
            }
          }
          break;

        case 'answer':
          if (_isBroadcaster) {
            _retryTimer?.cancel();
            _hasReceivedAnswer = true;
            final sdp = data['sdp'] as String?;
            if (sdp != null) {
              final description = RTCSessionDescription(sdp, 'answer');
              await _peerConnection!.setRemoteDescription(description);
              _remoteDescriptionSet = true;
              await _flushPendingCandidates();
              onStreamStateChange?.call(SosStreamState.streaming);
            }
          }
          break;

        case 'candidate':
          final candidateStr = data['candidate'] as String?;
          final sdpMid = data['sdpMid'] as String?;
          final sdpMLineIndex = data['sdpMLineIndex'] as int?;

          if (candidateStr != null) {
            final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
            if (_remoteDescriptionSet && _peerConnection != null) {
              await _peerConnection!.addCandidate(candidate);
            } else {
              _pendingCandidates.add(candidate);
            }
          }
          break;

        case 'stream_ended':
          onViewerLeft?.call();
          onStreamStateChange?.call(SosStreamState.ended);
          await cleanUp();
          break;
      }
    } catch (e, st) {
      _logger.e('SosStreaming._handleSignal error ($type): $e\n$st');
    }
  }

  Future<void> _createAndSendOffer(String sessionId, String myUserId) async {
    if (_hasCreatedOffer && _remoteDescriptionSet) {
      _retransmitLocalCandidates(sessionId, myUserId);
      return;
    }

    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _hasCreatedOffer = true;

      _startHandshakeRetry(sessionId, myUserId, 'offer', {'sdp': offer.sdp});
      _retransmitLocalCandidates(sessionId, myUserId);
    } catch (e) {
      _logger.e('SosStreaming._createAndSendOffer error: $e');
    }
  }

  void _startHandshakeRetry(
    String sessionId,
    String myUserId,
    String type,
    Map<String, dynamic> data,
  ) {
    _retryTimer?.cancel();
    _retryCount = 0;

    _broadcastSignal(sessionId, myUserId, type, data);

    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      _retryCount++;

      if (type == 'guardian_joined' && (_hasCreatedOffer || _remoteDescriptionSet)) {
        timer.cancel();
        return;
      }
      if (type == 'offer' && _hasReceivedAnswer) {
        timer.cancel();
        return;
      }

      if (_retryCount >= _maxRetries) {
        timer.cancel();
        return;
      }

      _broadcastSignal(sessionId, myUserId, type, data);
    });
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        _logger.w('SosStreaming: Gagal flush pending candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }

  void _retransmitLocalCandidates(String sessionId, String myUserId) {
    for (final candidateMap in _myLocalCandidates) {
      _broadcastSignal(sessionId, myUserId, 'candidate', candidateMap);
    }
  }

  void _broadcastSignal(
    String sessionId,
    String myUserId,
    String type,
    Map<String, dynamic> data,
  ) {
    if (_channel == null) return;
    try {
      _channel!.sendBroadcastMessage(
        event: 'sos_signal',
        payload: {
          'session_id': sessionId,
          'sender_id': myUserId,
          'type': type,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      _logger.w('SosStreaming: Gagal broadcast signal $type: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Kontrol Kamera & Mic (Broadcaster)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks[0]);
    }
  }

  void setMicrophoneEnabled(bool enabled) {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  void setCameraEnabled(bool enabled) {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Cleanup (Idempoten)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> stopStream(String sessionId, String myUserId) async {
    _broadcastSignal(sessionId, myUserId, 'stream_ended', {});
    await cleanUp();
  }

  Future<void> cleanUp() async {
    if (_isCleaningUp || _isCleanedUp) return;
    _isCleaningUp = true;

    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingCandidates.clear();
    _myLocalCandidates.clear();

    if (_channel != null) {
      try {
        await _client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      try {
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      try {
        await _remoteStream!.dispose();
      } catch (_) {}
      _remoteStream = null;
    }

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (_) {}
      _peerConnection = null;
    }

    _isCleaningUp = false;
    _isCleanedUp = true;
    _logger.i('SosStreamingService: Selesai dibersihkan.');
  }
}
