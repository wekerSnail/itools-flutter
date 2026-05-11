import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? shad.colorScheme.card,
        border: Border.all(color: borderColor ?? shad.colorScheme.border),
        borderRadius:
            borderRadius ?? BorderRadius.circular(BorderRadiusTokens.lg),
        boxShadow: boxShadow ?? Shadows.sm,
      ),
      padding: padding,
      child: child,
    );
  }
}

class InteractiveSurfaceCard extends StatefulWidget {
  const InteractiveSurfaceCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.isSelected = false,
    this.expand = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool isSelected;
  final bool expand;

  @override
  State<InteractiveSurfaceCard> createState() =>
      _InteractiveSurfaceCardState();
}

class _InteractiveSurfaceCardState extends State<InteractiveSurfaceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final isInteractive = widget.onTap != null;
    final borderColor = widget.isSelected
        ? shad.colorScheme.primary
        : _hovered
        ? shad.colorScheme.ring
        : shad.colorScheme.border;
    final backgroundColor = widget.isSelected
        ? shad.colorScheme.primary.withValues(alpha: 0.05)
        : _hovered
        ? shad.colorScheme.accent.withValues(alpha: 0.55)
        : shad.colorScheme.card;
    final shadow = widget.isSelected || _hovered
        ? <BoxShadow>[
            ...Shadows.md,
            BoxShadow(
              color: shad.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
        : Shadows.sm;

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: AnimationDuration.hoverEffect,
          scale: _hovered && isInteractive ? 1.01 : 1,
          child: AnimatedContainer(
            duration: AnimationDuration.hoverEffect,
            width: widget.expand ? double.infinity : null,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 1.2),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              boxShadow: shadow,
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class PageSectionHeader extends StatelessWidget {
  const PageSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: shad.colorScheme.primary),
                    const SizedBox(width: Spacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Typography.h4.copyWith(
                        color: shad.colorScheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle!,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Spacing.md),
          trailing!,
        ],
      ],
    );
  }
}
