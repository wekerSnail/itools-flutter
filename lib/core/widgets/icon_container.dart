import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 标准 44×44 图标容器（UI Style Guide）。
class IconContainer extends StatelessWidget {
  const IconContainer({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 18,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: shad.colorScheme.secondary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: shad.colorScheme.secondaryForeground,
      ),
    );
  }
}
