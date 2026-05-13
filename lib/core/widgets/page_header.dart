import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 统一的页面顶部导航栏，替代 Material AppBar。
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: shad.colorScheme.background,
        border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
        boxShadow: Shadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        children: [
          if (showBack) ...[
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.arrowLeft, size: 15),
                  SizedBox(width: 4),
                  Text('返回'),
                ],
              ),
            ),
            Container(
              height: Spacing.md,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
              color: shad.colorScheme.border,
            ),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Typography.h4.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
