import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/webrtc_config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // Configurations for WebRTC STUN/TURN servers (Centralized via WebRtcConfig)
  final Map<String, dynamic> _iceServers = WebRtcConfig.buildIceConfiguration();

  // Get local media stream (camera & microphone)
  Future<MediaStream> getLocalStream({bool audio = true, bool video = true, bool isFrontCamera = true}) async {
    // If stream already exists, dispose it first
    await disposeLocalStream();

    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': isFrontCamera ? 'user' : 'environment',
              'optional': [],
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return _localStream!;
  }

  // Initialize RTCPeerConnection
  Future<RTCPeerConnection> createPeerConnectionInstance() async {
    _peerConnection = await createPeerConnection(_iceServers);
    
    // Add local stream tracks to peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }
    
    return _peerConnection!;
  }

  // Switch camera between front and back
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      await Helper.switchCamera(videoTrack);
    }
  }

  // Toggle microphone
  void setMicrophoneEnabled(bool enabled) {
    if (_localStream != null) {
      final audioTrack = _localStream!
          .getAudioTracks()
          .firstWhere((track) => track.kind == 'audio');
      audioTrack.enabled = enabled;
    }
  }

  // Toggle camera
  void setCameraEnabled(bool enabled) {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      videoTrack.enabled = enabled;
    }
  }

  // Dispose stream
  Future<void> disposeLocalStream() async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
  }

  // Clean connection
  Future<void> cleanUp() async {
    await disposeLocalStream();
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
  }
}
