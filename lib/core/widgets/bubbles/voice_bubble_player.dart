import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/aegis_shredder_service.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../constants/colors.dart';
import '../../constants/icons.dart';
import 'bubble_media_helper.dart';
import 'view_once_store.dart';

/// Voice Note Player (pemutar audio dengan status sekali lihat, waveform, dan progress)
class VoiceBubblePlayer extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;
  final Color textColor;

  const VoiceBubblePlayer({
    super.key,
    required this.message,
    required this.isMe,
    required this.textColor,
  });

  @override
  ConsumerState<VoiceBubblePlayer> createState() => _VoiceBubblePlayerState();
}

class _VoiceBubblePlayerState extends ConsumerState<VoiceBubblePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  File? _downloadedFile;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _position = Duration.zero);
      if (widget.message.isViewOnce) {
        ViewOnceStore.markViewed(widget.message.id);
        try {
          ref.read(chatActionsProvider).markViewOnceOpened(widget.message.id);
        } catch (_) {}
        final temp = _downloadedFile;
        if (temp != null && temp.existsSync()) {
          unawaited(AegisShredderService.instance.shredFile(temp.path));
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    if (widget.message.isViewOnce) {
      final temp = _downloadedFile;
      if (temp != null && temp.existsSync()) {
        unawaited(AegisShredderService.instance.shredFile(temp.path));
      }
    }
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        setState(() => _isLoading = true);
        final file = await getOrDecryptMedia(
          messageId: widget.message.id,
          url: url,
          isEncrypted: widget.message.isEncrypted,
          fileKeyB64: widget.message.content,
        );
        if (file != null) {
          _downloadedFile = file;
          await _player.play(DeviceFileSource(file.path));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isViewOnce) {
      return FutureBuilder<bool>(
        future: ViewOnceStore.isViewed(widget.message.id),
        initialData: widget.message.isOpened,
        builder: (ctx, snap) {
          final alreadyViewed = widget.message.isOpened || (snap.data ?? false);
          if (alreadyViewed) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MekaarIcons.visibilityOff,
                    color: Colors.white54,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Pesan suara telah diputar',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return _buildPlayerRow(context);
        },
      );
    }
    return _buildPlayerRow(context);
  }

  Widget _buildPlayerRow(BuildContext context) {
    final accentColor = MekaarColors.accentOf(context);
    final mainColor = widget.isMe ? widget.textColor : accentColor;
    final activeWave = widget.isMe ? widget.textColor : accentColor;
    final inactiveWave = widget.isMe
        ? widget.textColor.withValues(alpha: 0.35)
        : MekaarColors.textMutedOf(context).withValues(alpha: 0.35);

    return GestureDetector(
      onTap: _togglePlay,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mainColor,
                  ),
                ),
              ),
            )
          else
            Icon(
              _isPlaying
                  ? MekaarIcons.pauseCircleFilled
                  : MekaarIcons.playCircleFilled,
              size: 32,
              color: mainColor,
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            height: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(15, (index) {
                final played = (index / 15) <= _progress;
                return Container(
                  width: 3,
                  height: (4 + (index % 4) * 3.0).toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: played ? activeWave : inactiveWave,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label(),
            style: TextStyle(
              color: widget.isMe
                  ? widget.textColor.withValues(alpha: 0.8)
                  : MekaarColors.textMutedOf(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    if (_isPlaying || _position > Duration.zero) {
      final m = _position.inMinutes;
      final s = _position.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    if (_duration > Duration.zero) {
      final m = _duration.inMinutes;
      final s = _duration.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '0:00';
  }
}
