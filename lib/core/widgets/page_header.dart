import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return Material(
      elevation: 0,
      color: shad.colorScheme.background,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: shad.colorScheme.background,
          border: Border(
            bottom: BorderSide(color: shad.colorScheme.border),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            if (showBack) ...[
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.arrowLeft, size: 15),
                    const SizedBox(width: 4),
                    const Text('返回'),
                  ],
                ),
              ),
              Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: shad.colorScheme.border,
              ),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: shad.textTheme.h4),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: shad.textTheme.muted),
                ],
              ],
            ),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}
