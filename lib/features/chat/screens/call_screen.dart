import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/webrtc_signaling_service.dart';
import '../../auth/providers/auth_provider.dart';


class CallScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String chatName;
  final String callerId;
  final String receiverId;
  final bool isCaller;
  final String callType; // 'voice' or 'video'

  const CallScreen({
    super.key,
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

class _CallScreenState extends ConsumerState<CallScreen> {
  late final WebRtcSignalingService _signaling;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = true;
  String _callStatus = 'Menghubungkan...';
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = ref.read(authProvider).user?.id;
    _isVideoOn = widget.callType == 'video';
    
    _initRenderers();
    _initSignaling();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _initSignaling() async {
    final supabase = Supabase.instance.client;
    _signaling = WebRtcSignalingService(supabase);

    _signaling.onLocalStream = (stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };

    _signaling.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    };

    _signaling.onCallStateChange = (state) {
      if (mounted) {
        setState(() {
          if (state == 'calling') {
            _callStatus = 'Memanggil...';
          } else if (state == 'ringing') {
            _callStatus = 'Berdering...';
          } else if (state == 'connected') {
            _callStatus = 'Tersambung';
          } else {
            _callStatus = state;
          }
        });
      }
    };

    _signaling.onHangup = () {
      if (mounted) {
        Navigator.pop(context);
      }
    };

    // First setup media (audio & video if enabled)
    await _signaling.initMedia(_isVideoOn);
    
    // Start signaling connection
    await _signaling.startSignaling(
      widget.roomId,
      _myUserId ?? '',
      widget.isCaller,
      _isVideoOn,
    );
  }

  void _toggleMute() {
    if (_signaling.localStream != null) {
      final audioTracks = _signaling.localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final state = !audioTracks[0].enabled;
        audioTracks[0].enabled = state;
        setState(() => _isMuted = !state);
      }
    }
  }

  void _toggleSpeaker() {
    if (_signaling.localStream != null) {
      // Direct WebRTC speakerphone toggle
      Helper.selectAudioOutput(_isSpeakerOn ? 'earpiece' : 'speaker');
      setState(() => _isSpeakerOn = !_isSpeakerOn);
    }
  }

  void _toggleVideo() {
    if (_signaling.localStream != null && widget.callType == 'video') {
      final videoTracks = _signaling.localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final state = !videoTracks[0].enabled;
        videoTracks[0].enabled = state;
        setState(() => _isVideoOn = state);
      }
    }
  }

  void _hangup() {
    _signaling.hangup(_myUserId ?? '');
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling.cleanUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Stream Renderer (Full Screen for video calls)
          if (isVideoCall && _remoteRenderer.srcObject != null)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Dark overlay gradient for video call text readability
          if (isVideoCall)
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

          // Caller Info
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (!isVideoCall) ...[
                  // Voice call avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: MekaarColors.softCoral,
                    child: Text(
                      widget.chatName.isNotEmpty ? widget.chatName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                Text(
                  _callStatus,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Local Stream Renderer (Small Overlay for video calls)
          if (isVideoCall && _isVideoOn && _localRenderer.srcObject != null)
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

          // Call Controls Row
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speakerphone button
                _controlButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  color: _isSpeakerOn ? Colors.white : Colors.white24,
                  iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                  onTap: _toggleSpeaker,
                ),

                // Video toggle button (only visible for video calls)
                if (isVideoCall)
                  _controlButton(
                    icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    color: _isVideoOn ? Colors.white : Colors.white24,
                    iconColor: _isVideoOn ? Colors.black : Colors.white,
                    onTap: _toggleVideo,
                  ),

                // Microphone Mute button
                _controlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.white : Colors.white24,
                  iconColor: _isMuted ? Colors.black : Colors.white,
                  onTap: _toggleMute,
                ),

                // Hangup button
                _controlButton(
                  icon: Icons.call_end,
                  color: MekaarColors.sosRed,
                  iconColor: Colors.white,
                  onTap: _hangup,
                  size: 64,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}
