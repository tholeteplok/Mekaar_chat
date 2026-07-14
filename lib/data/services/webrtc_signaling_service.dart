import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebRtcSignalingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // Configuration for ICE candidate exchange
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  // Callbacks for UI updates
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(String state)? onCallStateChange;
  Function()? onHangup;

  WebRtcSignalingService(this._client);

  /// Initialize local media streams
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
          : false
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (onLocalStream != null) {
      onLocalStream!(localStream!);
    }
  }

  /// Start signaling channel and peer connection
  Future<void> startSignaling(String roomId, String myUserId, bool isCaller, bool isVideo) async {
    // 1. Create Peer Connection
    _peerConnection = await createPeerConnection(_configuration);

    // Add local stream tracks to Peer Connection
    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, localStream!);
      });
    }

    // 2. Setup ICE Candidate listener
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendSignal(myUserId, 'candidate', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // 3. Setup Remote Stream listener
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onRemoteStream != null) {
          onRemoteStream!(remoteStream!);
        }
      }
    };

    // 4. Connect to Supabase Realtime Channel
    _channel = _client.channel('room_call:$roomId');

    _channel!.onBroadcast(
      event: 'signal',
      callback: (payload) async {
        final sender = payload['sender'] as String;
        // Ignore signals sent by myself
        if (sender == myUserId) return;

        final type = payload['type'] as String;
        final data = payload['data'] as Map<String, dynamic>?;

        switch (type) {
          case 'offer':
            if (!isCaller && data != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'], data['type']),
              );
              // Create Answer
              final answer = await _peerConnection!.createAnswer();
              await _peerConnection!.setLocalDescription(answer);
              _sendSignal(myUserId, 'answer', {
                'sdp': answer.sdp,
                'type': answer.type,
              });
              if (onCallStateChange != null) {
                onCallStateChange!('connected');
              }
            }
            break;

          case 'answer':
            if (isCaller && data != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'], data['type']),
              );
              if (onCallStateChange != null) {
                onCallStateChange!('connected');
              }
            }
            break;

          case 'candidate':
            if (data != null) {
              await _peerConnection!.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
            break;

          case 'hangup':
            cleanUp();
            if (onHangup != null) {
              onHangup!();
            }
            break;
        }
      },
    );

    _channel!.subscribe();

    // 5. If caller, create SDP Offer
    if (isCaller) {
      if (onCallStateChange != null) {
        onCallStateChange!('calling');
      }
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _sendSignal(myUserId, 'offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    } else {
      if (onCallStateChange != null) {
        onCallStateChange!('ringing');
      }
    }
  }

  /// Sends persistence signal to other party
  void _sendSignal(String senderId, String type, Map<String, dynamic> data) {
    _channel?.sendBroadcastMessage(
      event: 'signal',
      payload: {
        'sender': senderId,
        'type': type,
        'data': data,
      },
    );
  }



  /// Triggered when hang up
  void hangup(String myUserId) {
    _sendSignal(myUserId, 'hangup', {});
    cleanUp();
    if (onHangup != null) {
      onHangup!();
    }
  }

  /// Clean resources up
  void cleanUp() {
    _channel?.unsubscribe();
    _channel = null;

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;

    remoteStream?.dispose();
    remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }
}
