import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebRtcSignalingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final Map<String, dynamic> _configuration;

  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  bool _hasCreatedOffer = false;
  bool _isCleaningUp = false;
  bool _isCleanedUp = false;

  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(String state)? onCallStateChange;
  Function()? onHangup;
  Function(Object error)? onError;

  // Konfigurasi ICE/TURN server.
  //
  // PRODUKSI: kredensial TURN publik/gratis (openrelay.metered.ca) TIDAK
  // punya SLA dan bisa mati/dibatasi kapan saja — fatal untuk fitur video/
  // audio darurat SOS. Set TURN server privat lewat --dart-define saat build:
  //
  //   flutter build apk \
  //     --dart-define=TURN_URL=turn:turn.contoh-domain.com:3478 \
  //     --dart-define=TURN_USERNAME=xxxx \
  //     --dart-define=TURN_CREDENTIAL=yyyy
  //
  // (bisa pakai coturn self-hosted, atau layanan terkelola seperti Twilio
  // Network Traversal Service / Cloudflare Calls / Metered.ca berbayar).
  // Jika TURN_URL tidak diisi, fallback ke relay publik HANYA untuk
  // development/testing lokal — jangan pernah rilis produksi dengan fallback
  // ini aktif.
  static const String _turnUrl = String.fromEnvironment('TURN_URL');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential = String.fromEnvironment(
    'TURN_CREDENTIAL',
  );

  static Map<String, dynamic> _buildDefaultConfiguration() {
    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
    ];

    if (_turnUrl.isNotEmpty) {
      iceServers.add({
        'urls': _turnUrl,
        'username': _turnUsername,
        'credential': _turnCredential,
      });
    } else {
      // ⚠️ DEV-ONLY fallback — lihat catatan di atas. Tidak boleh dipakai
      // untuk build produksi/rilis publik.
      if (kDebugMode) {
        debugPrint(
          '⚠️ WebRtcSignalingService: TURN_URL tidak diset, memakai relay '
          'publik openrelay.metered.ca (DEV ONLY). Set --dart-define=TURN_URL '
          '(+ TURN_USERNAME/TURN_CREDENTIAL) sebelum build produksi.',
        );
      }
      iceServers.addAll(const [
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ]);
    }

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
  }

  static final Map<String, dynamic> _defaultConfiguration =
      _buildDefaultConfiguration();

  WebRtcSignalingService(this._client, {Map<String, dynamic>? configuration})
    : _configuration = configuration ?? _defaultConfiguration;

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

  Future<void> startSignaling(
    String roomId,
    String myUserId,
    bool isCaller,
    bool isVideo,
  ) async {
    try {
      _peerConnection = await createPeerConnection(_configuration);

      if (localStream != null) {
        for (final track in localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, localStream!);
        }
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _sendSignal(myUserId, 'candidate', {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
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

      _channel = _client.channel('room_call:$roomId');

      _channel!.onBroadcast(
        event: 'signal',
        callback: (payload) async {
          await _handleSignal(payload, myUserId, isCaller);
        },
      );

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

      await subscribed.future;

      if (_isCleaningUp || _isCleanedUp || _channel == null) {
        return;
      }

      if (isCaller) {
        if (onCallStateChange != null) {
          onCallStateChange!('calling');
        }
        // Kirim sinyal caller_ready untuk memberi tahu receiver jika receiver sudah subscribe
        await _sendSignal(myUserId, 'caller_ready', {});
      } else {
        if (onCallStateChange != null) {
          onCallStateChange!('ringing');
        }
        // Penerima langsung mengirim sinyal 'joined' ke kanal
        await _sendSignal(myUserId, 'joined', {});
      }
    } catch (error) {
      _emitError(error);
      rethrow;
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
            await _sendSignal(myUserId, 'joined', {});
          }
          break;

        case 'joined':
          if (isCaller && !_hasCreatedOffer) {
            _hasCreatedOffer = true;
            final offer = await connection.createOffer();
            await connection.setLocalDescription(offer);
            await _sendSignal(myUserId, 'offer', {
              'sdp': offer.sdp,
              'type': offer.type,
            });
          }
          break;

        case 'offer':
          if (!isCaller && data != null) {
            await connection.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']),
            );
            _remoteDescriptionSet = true;
            await _flushPendingCandidates();

            final answer = await connection.createAnswer();
            await connection.setLocalDescription(answer);
            await _sendSignal(myUserId, 'answer', {
              'sdp': answer.sdp,
              'type': answer.type,
            });
          }
          break;

        case 'answer':
          if (isCaller && data != null) {
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

    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _hasCreatedOffer = false;

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
    if (onError != null) {
      onError!(error);
    }
  }
}
