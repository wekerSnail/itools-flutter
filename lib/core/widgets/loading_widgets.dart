import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design_tokens/index.dart';

/// Loading skeleton shimmer widget
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius,
    super.key,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.95,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: shad.colorScheme.secondary.withValues(alpha: 0.45),
          borderRadius:
              widget.borderRadius ??
              BorderRadius.circular(BorderRadiusTokens.md),
        ),
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    super.key,
  });

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

/// Custom loading spinner
class ModernLoadingSpinner extends StatefulWidget {
  final Color? color;
  final double size;

  const ModernLoadingSpinner({this.color, this.size = 40, super.key});

  @override
  State<ModernLoadingSpinner> createState() => _ModernLoadingSpinnerState();
}

class _ModernLoadingSpinnerState extends State<ModernLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final indicatorColor = widget.color ?? shad.colorScheme.primary;

    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: indicatorColor.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border(
                  top: BorderSide(color: indicatorColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
