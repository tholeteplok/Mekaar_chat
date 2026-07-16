import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// Balok skeleton generik untuk state loading, dibungkus efek shimmer.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = MekaarRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Membungkus konten skeleton dengan gradient shimmer yang mengikuti tema.
class MekaarShimmer extends StatelessWidget {
  final Widget child;

  const MekaarShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? MekaarColors.surfaceDark : MekaarColors.surface3,
      highlightColor:
          isDark ? MekaarColors.surface : MekaarColors.borderLight,
      child: child,
    );
  }
}

/// Placeholder skeleton untuk satu baris daftar chat.
class ChatListSkeleton extends StatelessWidget {
  final int itemCount;

  const ChatListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return MekaarShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: MekaarSpacing.xl,
          vertical: MekaarSpacing.sm,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: MekaarSpacing.sm),
          child: Row(
            children: [
              const SkeletonBox(
                width: MekaarSizes.avatarLg,
                height: MekaarSizes.avatarLg,
                radius: MekaarRadius.pill,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: MekaarSpacing.sm),
                    SkeletonBox(width: 220, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
