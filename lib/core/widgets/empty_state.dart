import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// Empty state placeholder used by list pages.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            ),
            child: Icon(
              icon,
              size: 32,
              color: shad.colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            title,
            style: Typography.h3.copyWith(color: shad.colorScheme.foreground),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              description!,
              style: Typography.bodySmall.copyWith(
                color: shad.colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Spacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
