import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
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
  final String? searchHint;

  @override
  State<MekaarTabHeader> createState() => _MekaarTabHeaderState();
}

class _MekaarTabHeaderState extends State<MekaarTabHeader> {
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
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
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchMode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBg = isDark
        ? MekaarColors.surface2Of(context).withValues(alpha: 0.75)
        : MekaarColors.surface2Of(context);

    return Container(
      key: const ValueKey('search_mode_header'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: searchBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MekaarColors.cardBorderOf(context).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            SolarIconsOutline.magnifier,
            color: MekaarColors.textSecondaryOf(context),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Cari...',
                hintStyle: MekaarTypography.bodyMD.copyWith(
                  color: MekaarColors.textSecondaryOf(context),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.searchController != null &&
              widget.searchController!.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.searchController!.clear();
                widget.onSearchChanged?.call('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  SolarIconsOutline.closeCircle,
                  color: MekaarColors.textSecondaryOf(context),
                  size: 18,
                ),
              ),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              _searchFocusNode.unfocus();
              widget.onSearchClosed?.call();
            },
            child: Text(
              'Batal',
              style: MekaarTypography.labelMD.copyWith(
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalMode() {
    final titleText = Text(
      widget.title,
      style: MekaarTypography.headingLG.copyWith(
        color: MekaarColors.textPrimaryOf(context),
        letterSpacing: -0.5,
        fontWeight: FontWeight.w800,
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
              titleText,
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
