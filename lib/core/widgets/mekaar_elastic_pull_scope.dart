import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/haptic_service.dart';

/// Koordinator gesture tarik layar (*elastic pull-down overscroll*) 2-tier ala Telegram.
///
/// Mendengarkan [ScrollNotification] dari scrollable turunan:
/// 1. Tarik Tahap 1 ([threshold1], default 55dp): Membuka search bar di bawah header.
/// 2. Tarik Tahap 2 ([threshold2], default 105dp): Memicu refresh/sinkronisasi asinkron.
/// 3. Lepas di Tahap 1: Search bar tetap terbuka (*sticky*).
/// 4. Lepas di Tahap 2: Menjalankan [onRefresh] dan mengunci search bar terbuka.
/// 5. Scroll ke bawah (konten): Melipat kembali search bar jika teks pencarian kosong.
class MekaarElasticPullScope extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final bool isSearchActive;
  final ValueChanged<bool> onSearchActiveChanged;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<double>? onPullProgressChanged;
  final ValueChanged<bool>? onRefreshingChanged;
  final double threshold1;
  final double threshold2;

  const MekaarElasticPullScope({
    super.key,
    required this.child,
    required this.isSearchActive,
    required this.onSearchActiveChanged,
    this.onRefresh,
    this.searchController,
    this.searchFocusNode,
    this.onPullProgressChanged,
    this.onRefreshingChanged,
    this.threshold1 = 55.0,
    this.threshold2 = 105.0,
  });

  @override
  State<MekaarElasticPullScope> createState() => _MekaarElasticPullScopeState();
}

class _MekaarElasticPullScopeState extends State<MekaarElasticPullScope> {
  double _dragDistance = 0.0;
  bool _isUserDragging = false;
  bool _hasTriggeredHaptic1 = false;
  bool _hasTriggeredHaptic2 = false;
  bool _isRefreshing = false;

  void _updateProgress(double distance) {
    final progress = (distance / widget.threshold1).clamp(0.0, 1.0);
    widget.onPullProgressChanged?.call(progress);

    if (distance >= widget.threshold1 && !_hasTriggeredHaptic1) {
      _hasTriggeredHaptic1 = true;
      HapticService.trigger(MekaarHapticIntent.selection);
    } else if (distance < widget.threshold1) {
      _hasTriggeredHaptic1 = false;
    }

    if (distance >= widget.threshold2 && !_hasTriggeredHaptic2) {
      _hasTriggeredHaptic2 = true;
      HapticService.trigger(MekaarHapticIntent.warning);
    } else if (distance < widget.threshold2) {
      _hasTriggeredHaptic2 = false;
    }
  }

  void _onUserRelease() {
    if (!_isUserDragging) return;
    _isUserDragging = false;
    final releasedDistance = _dragDistance;
    _dragDistance = 0.0;
    _updateProgress(0.0);
    _hasTriggeredHaptic1 = false;
    _hasTriggeredHaptic2 = false;

    if (releasedDistance >= widget.threshold2) {
      if (!widget.isSearchActive) {
        widget.onSearchActiveChanged(true);
      }
      unawaited(_handleRefresh());
    } else if (releasedDistance >= widget.threshold1) {
      if (!widget.isSearchActive) {
        widget.onSearchActiveChanged(true);
      }
    }
  }

  @override
  void dispose() {
    if (_isRefreshing) {
      final callback = widget.onRefreshingChanged;
      if (callback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          callback(false);
        });
      }
    }
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    widget.onRefreshingChanged?.call(true);

    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        widget.onRefreshingChanged?.call(false);
      } else {
        final callback = widget.onRefreshingChanged;
        if (callback != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            callback(false);
          });
        }
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    // 1. Deteksi awal drag pengguna
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isUserDragging = true;
        _dragDistance = 0.0;
      }
    }

    // 2. Deteksi tarikan overscroll ke bawah saat di puncak (pixels < 0 pada Bouncing)
    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) {
        _isUserDragging = true;
        final pixels = notification.metrics.pixels;
        if (pixels < 0) {
          _dragDistance = -pixels;
          _updateProgress(_dragDistance);
        } else {
          if (_dragDistance > 0) {
            _dragDistance = 0.0;
            _updateProgress(0.0);
          }
        }
      } else if (_isUserDragging) {
        // Drag details menjadi null -> user melepaskan jari ke fase balistik
        _onUserRelease();
      }

      // Deteksi scroll konten ke bawah untuk melipat search bar (auto-collapse)
      if (notification.metrics.pixels > 20 &&
          (notification.scrollDelta ?? 0) > 0) {
        final hasQuery =
            widget.searchController?.text.trim().isNotEmpty ?? false;
        if (widget.isSearchActive && !hasQuery) {
          widget.searchFocusNode?.unfocus();
          widget.onSearchActiveChanged(false);
        }
      }
    } else if (notification is OverscrollNotification) {
      if (notification.dragDetails != null) {
        _isUserDragging = true;
        if (notification.overscroll < 0) {
          _dragDistance += -notification.overscroll;
          _updateProgress(_dragDistance);
        }
      }
    }

    // 3. Deteksi idle atau akhir scroll
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle && _isUserDragging) {
        _onUserRelease();
      }
    } else if (notification is ScrollEndNotification) {
      if (_isUserDragging) {
        _onUserRelease();
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: widget.child,
    );
  }
}
