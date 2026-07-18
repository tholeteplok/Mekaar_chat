import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

/// Header visual yang konsisten untuk halaman utama pada bottom navigation.
class MekaarTabHeader extends StatelessWidget {
  const MekaarTabHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: MekaarGradients.coral.createShader,
                child: Text(title, style: MekaarTypography.tabHeader),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
      ),
    );
  }
}
