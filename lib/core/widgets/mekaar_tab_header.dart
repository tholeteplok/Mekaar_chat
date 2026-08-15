import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// Header visual yang konsisten untuk halaman utama pada bottom navigation.
///
/// Mendukung mode judul dengan subtitle (misal: [MekaarLiveSafetyPill])
/// serta transisi halus ke mode pencarian penuh (Expandable Search Bar).
class MekaarTabHeader extends StatefulWidget {
  const MekaarTabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.isSearchActive = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClosed,
    this.searchHint = 'Cari chat atau teman...',
  });

  final String title;
  final Widget? subtitle;
  final Widget? action;
  final bool isSearchActive;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClosed;
  final String searchHint;

  @override
  State<MekaarTabHeader> createState() => _MekaarTabHeaderState();
}

class _MekaarTabHeaderState extends State<MekaarTabHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant MekaarTabHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSearchActive && !oldWidget.isSearchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSearchMode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBg = isDark
        ? MekaarColors.surface2Of(context).withValues(alpha: 0.75)
        : MekaarColors.surface2Of(context);

    return Container(
      key: const ValueKey('search_mode_header'),
      height: 48,
      decoration: BoxDecoration(
        color: searchBg,
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(SolarIconsOutline.arrowLeft, size: 20),
            color: MekaarColors.textPrimaryOf(context),
            tooltip: 'Tutup Pencarian',
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              _searchFocusNode.unfocus();
              widget.onSearchClosed?.call();
            },
          ),
          Expanded(
            child: TextField(
              controller: widget.searchController,
              focusNode: _searchFocusNode,
              onChanged: widget.onSearchChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: MekaarColors.textPrimaryOf(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: TextStyle(
                  color: MekaarColors.textMutedOf(context),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (widget.searchController != null &&
              widget.searchController!.text.isNotEmpty)
            IconButton(
              icon: const Icon(SolarIconsOutline.closeCircle, size: 18),
              color: MekaarColors.textMutedOf(context),
              tooltip: 'Hapus Teks',
              onPressed: () {
                widget.searchController?.clear();
                widget.onSearchChanged?.call('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNormalMode() {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final titleText = Text(
      widget.title,
      style: MekaarTypography.displayLG.copyWith(
        color: MekaarColors.textPrimaryOf(context),
        fontSize: 26,
      ),
    );

    return Row(
      key: const ValueKey('normal_mode_header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              disableAnimations
                  ? titleText
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final t = _controller.value;
                        return ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) {
                            final sweepX = (t * 2.0 - 0.5) * bounds.width;
                            return LinearGradient(
                              colors: [
                                Colors.transparent,
                                MekaarColors.textPrimaryOf(context)
                                    .withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment(
                                (sweepX - bounds.width * 0.3) / bounds.width,
                                0,
                              ),
                              end: Alignment(
                                (sweepX + bounds.width * 0.3) / bounds.width,
                                0,
                              ),
                            ).createShader(bounds);
                          },
                          child: titleText,
                        );
                      },
                    ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                widget.subtitle!,
              ],
            ],
          ),
        ),
        if (widget.action != null) ...[
          const SizedBox(width: 8),
          widget.action!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: 0.0,
                child: child,
              ),
            );
          },
          child: widget.isSearchActive
              ? _buildSearchMode()
              : _buildNormalMode(),
        ),
      ),
    );
  }
}
