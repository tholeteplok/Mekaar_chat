import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/webrtc_config.dart';

class WebRtcSignalingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final Map<String, dynamic> _configuration;

  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];
  final List<Map<String, dynamic>> _myLocalCandidates = <Map<String, dynamic>>[];
  bool _remoteDescriptionSet = false;
  bool _hasCreatedOffer = false;
  bool _hasReceivedAnswer = false;
  bool _isCleaningUp = false;
  bool _isCleanedUp = false;

  /// Cache answer SDP agar bisa dikirim ulang saat menerima duplikat offer
  /// tanpa harus memanggil setRemoteDescription lagi (mencegah InvalidStateError).
  Map<String, dynamic>? _cachedAnswer;

  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 6;
  static const int _channelSubscribeMaxRetries = 2;
  static const Duration _channelRetryDelay = Duration(seconds: 2);

  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(String state)? onCallStateChange;
  Function()? onHangup;
  Function(Object error)? onError;

  WebRtcSignalingService(this._client, {Map<String, dynamic>? configuration})
    : _configuration = configuration ?? WebRtcConfig.buildIceConfiguration();

  Future<void> initMedia(bool videoEnabled) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': videoEnabled
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (onLocalStream != null && localStream != null) {
        onLocalStream!(localStream!);
      }
    } catch (error) {
      _emitError(error);
      rethrow;
    }
  }

  Future<void> startSignaling({
    required String roomId,
    required String callId,
    required String myUserId,
    required bool isCaller,
    required bool isVideo,
  }) async {
    try {
      _peerConnection = await createPeerConnection(_configuration);

      if (localStream != null) {
        for (final track in localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, localStream!);
        }
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          final candData = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };
          _myLocalCandidates.add(candData);
          _sendSignal(myUserId, 'candidate', candData);
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams[0];
          if (onRemoteStream != null) {
            onRemoteStream!(remoteStream!);
          }
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        _handleConnectionState(state);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        _handleIceConnectionState(state);
      };

      // Topik dispesifikkan ke ID panggilan unik (room_call:$callId)
      final channelTopic = 'room_call:$callId';
      _channel = _client.channel(channelTopic);

      _channel!.onBroadcast(
        event: 'signal',
        callback: (payload) async {
          await _handleSignal(payload, myUserId, isCaller);
        },
      );

      // Subscribe ke channel dengan retry untuk menangani WebSocket transient timeout
      await _subscribeChannelWithRetry(channelTopic, myUserId, isCaller);

      if (_isCleaningUp || _isCleanedUp || _channel == null) {
        return;
      }

      if (isCaller) {
        if (onCallStateChange != null) {
          onCallStateChange!('calling');
        }
        await _sendSignal(myUserId, 'caller_ready', {});
      } else {
        if (onCallStateChange != null) {
          onCallStateChange!('ringing');
        }
        // Penerima memancarkan sinyal 'joined' secara berkala (handshake retry)
        _startHandshakeRetry(myUserId, 'joined', {});
      }
    } catch (error) {
      _emitError(error);
      rethrow;
    }
  }

  void _startHandshakeRetry(String myUserId, String type, Map<String, dynamic> data) {
    _retryTimer?.cancel();
    _retryCount = 0;

    _sendSignal(myUserId, type, data);

    _retryTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_isCleaningUp || _isCleanedUp) {
        _retryTimer?.cancel();
        return;
      }

      if (type == 'joined' && (_hasCreatedOffer || _remoteDescriptionSet)) {
        _retryTimer?.cancel();
        return;
      }

      if (type == 'offer' && _hasReceivedAnswer) {
        _retryTimer?.cancel();
        return;
      }

      _retryCount++;
      if (_retryCount >= _maxRetries) {
        _retryTimer?.cancel();
        return;
      }

      _sendSignal(myUserId, type, data);
    });
  }

  /// Subscribe ke Supabase Realtime channel dengan retry otomatis.
  /// Menangani kasus WebSocket reconnect / transient timeout.
  Future<void> _subscribeChannelWithRetry(
    String channelTopic,
    String myUserId,
    bool isCaller,
  ) async {
    Object? lastError;

    for (int attempt = 0; attempt <= _channelSubscribeMaxRetries; attempt++) {
      if (_isCleaningUp || _isCleanedUp || _channel == null) {
        return;
      }

      // Jika bukan percobaan pertama, tunggu sebelum retry
      if (attempt > 0) {
        // Bersihkan channel lama dan buat ulang dengan config yang sama
        final oldChannel = _channel;
        if (oldChannel != null) {
          try {
            await oldChannel.unsubscribe();
          } catch (_) {}
          try {
            await _client.removeChannel(oldChannel);
          } catch (_) {}
        }

        await Future<void>.delayed(_channelRetryDelay);

        if (_isCleaningUp || _isCleanedUp) return;

        // Re-create channel dengan topic yang sama
        _channel = _client.channel(channelTopic);

        // Re-register broadcast handler pada channel baru
        _channel!.onBroadcast(
          event: 'signal',
          callback: (payload) async {
            await _handleSignal(payload, myUserId, isCaller);
          },
        );
      }

      final subscribed = Completer<void>();
      _channel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!subscribed.isCompleted) {
            subscribed.complete();
          }
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed) {
          final failure =
              error ??
              StateError('Gagal berlangganan kanal panggilan: ${status.name}');
          if (!subscribed.isCompleted) {
            subscribed.completeError(failure);
          } else {
            _emitError(failure);
          }
        }
      });

      try {
        await subscribed.future;
        return; // Berhasil subscribe
      } catch (e) {
        lastError = e;
        if (attempt < _channelSubscribeMaxRetries) {
          _emitError(StateError(
            'Subscribe kanal gagal (percobaan ${attempt + 1}/${_channelSubscribeMaxRetries + 1}), retry...',
          ));
        }
      }
    }

    // Semua percobaan gagal
    throw lastError ?? StateError('Gagal berlangganan kanal panggilan setelah retry');
  }

  /// Pemicu manual pembentukan Offer (dipanggil jika DB status = 'answered' tetapi broadcast 'joined' terlewati)
  Future<void> createOfferIfPending(String myUserId) async {
    final connection = _peerConnection;
    if (connection == null || _hasCreatedOffer || _isCleaningUp || _isCleanedUp) {
      return;
    }

    try {
      _hasCreatedOffer = true;
      final offer = await connection.createOffer();
      await connection.setLocalDescription(offer);
      
      final offerData = {
        'sdp': offer.sdp,
        'type': offer.type,
      };

      _myLocalCandidates.clear();
      _startHandshakeRetry(myUserId, 'offer', offerData);
      _retransmitLocalCandidates(myUserId);
    } catch (error) {
      _emitError(error);
    }
  }

  void _retransmitLocalCandidates(String myUserId) {
    for (final candData in _myLocalCandidates) {
      _sendSignal(myUserId, 'candidate', candData);
    }
  }

  Future<void> _handleSignal(
    Map<String, dynamic> payload,
    String myUserId,
    bool isCaller,
  ) async {
    try {
      final sender = payload['sender'] as String?;
      if (sender == null || sender == myUserId) {
        return;
      }

      final type = payload['type'] as String?;
      final data = payload['data'] as Map<String, dynamic>?;
      final connection = _peerConnection;
      if (type == null || connection == null) {
        return;
      }

      switch (type) {
        case 'caller_ready':
          if (!isCaller) {
            _startHandshakeRetry(myUserId, 'joined', {});
          }
          break;

        case 'joined':
          if (isCaller && !_hasCreatedOffer) {
            await createOfferIfPending(myUserId);
          } else if (isCaller && _hasCreatedOffer) {
            _retransmitLocalCandidates(myUserId);
          }
          break;

        case 'offer':
          if (!isCaller && data != null) {
            _retryTimer?.cancel();

            // Guard duplikat offer: jika answer sudah di-cache, kirim ulang
            // tanpa memanggil setRemoteDescription lagi (mencegah InvalidStateError).
            if (_cachedAnswer != null && _remoteDescriptionSet) {
              await _sendSignal(myUserId, 'answer', _cachedAnswer!);
              _retransmitLocalCandidates(myUserId);
              break;
            }

            await connection.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
            _remoteDescriptionSet = true;
            await _flushPendingCandidates();

            final answer = await connection.createAnswer();
            await connection.setLocalDescription(answer);
            
            final answerData = {
              'sdp': answer.sdp,
              'type': answer.type,
            };

            // Cache answer untuk retransmisi saat menerima duplikat offer
            _cachedAnswer = answerData;

            await _sendSignal(myUserId, 'answer', answerData);
            _retransmitLocalCandidates(myUserId);
          }
          break;

        case 'answer':
          if (isCaller && data != null) {
            _retryTimer?.cancel();
            _hasReceivedAnswer = true;
            await connection.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
            _remoteDescriptionSet = true;
            await _flushPendingCandidates();
          }
          break;

        case 'candidate':
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            if (_remoteDescriptionSet) {
              await connection.addCandidate(candidate);
            } else {
              _pendingCandidates.add(candidate);
            }
          }
          break;

        case 'hangup':
          await cleanUp();
          if (onHangup != null) {
            onHangup!();
          }
          break;
      }
    } catch (error) {
      _emitError(error);
    }
  }

  Future<void> _flushPendingCandidates() async {
    final connection = _peerConnection;
    if (connection == null || _pendingCandidates.isEmpty) {
      return;
    }
    final candidates = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      try {
        await connection.addCandidate(candidate);
      } catch (error) {
        _emitError(error);
      }
    }
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    if (onCallStateChange == null) {
      return;
    }
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _retryTimer?.cancel();
        onCallStateChange!('connected');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        onCallStateChange!('disconnected');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        onCallStateChange!('failed');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        onCallStateChange!('closed');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        break;
    }
  }

  void _handleIceConnectionState(RTCIceConnectionState state) {
    if (onCallStateChange == null) {
      return;
    }
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _retryTimer?.cancel();
        onCallStateChange!('connected');
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        onCallStateChange!('failed');
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        onCallStateChange!('disconnected');
        break;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        onCallStateChange!('closed');
        break;
      default:
        break;
    }
  }

  Future<void> _sendSignal(
    String senderId,
    String type,
    Map<String, dynamic> data,
  ) async {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    try {
      await channel.sendBroadcastMessage(
        event: 'signal',
        payload: {'sender': senderId, 'type': type, 'data': data},
      );
    } catch (error) {
      _emitError(error);
    }
  }

  Future<void> hangup(String myUserId) async {
    _retryTimer?.cancel();
    await _sendSignal(myUserId, 'hangup', {});
    await cleanUp();
    if (onHangup != null) {
      onHangup!();
    }
  }

  Future<void> cleanUp() async {
    if (_isCleaningUp || _isCleanedUp) {
      return;
    }
    _isCleaningUp = true;
    _retryTimer?.cancel();

    _pendingCandidates.clear();
    _myLocalCandidates.clear();
    _cachedAnswer = null;
    _remoteDescriptionSet = false;
    _hasCreatedOffer = false;
    _hasReceivedAnswer = false;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }

    final local = localStream;
    localStream = null;
    if (local != null) {
      for (final track in local.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await local.dispose();
      } catch (_) {}
    }

    final remote = remoteStream;
    remoteStream = null;
    if (remote != null) {
      try {
        await remote.dispose();
      } catch (_) {}
    }

    final connection = _peerConnection;
    _peerConnection = null;
    if (connection != null) {
      try {
        await connection.close();
      } catch (_) {}
      try {
        await connection.dispose();
      } catch (_) {}
    }

    _isCleaningUp = false;
    _isCleanedUp = true;
  }

  void _emitError(Object error) {
    if (!_isCleanedUp && !_isCleaningUp && onError != null) {
      onError!(error);
    }
  }
}
