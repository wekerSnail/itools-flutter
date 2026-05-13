import 'package:flutter/widgets.dart';

import '../design_tokens/index.dart';

/// Page transition animation with fade + slide effect
class PageTransitionBuilder {
  static PageRoute<T> buildPageTransition<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        final offsetAnimation = animation.drive(tween);
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeAnimation),
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
    );
  }
}

/// Stagger animation for list items
class StaggeredAnimationBuilder extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration? staggerDuration;

  const StaggeredAnimationBuilder({
    required this.index,
    required this.child,
    this.staggerDuration,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final duration = staggerDuration ?? AnimationDuration.pageTransition;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Hover scale animation for interactive elements
class HoverScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scale;
  final Duration? duration;

  const HoverScaleButton({
    required this.child,
    required this.onPressed,
    this.scale = 0.95,
    this.duration,
    super.key,
  });

  @override
  State<HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<HoverScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? AnimationDuration.hoverEffect,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    _controller.forward();
  }

  void _onExit() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

/// Animated card with elevation and shadow on hover
class AnimatedElevatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Duration? duration;

  const AnimatedElevatedCard({
    required this.child,
    this.padding,
    this.backgroundColor,
    this.onTap,
    this.duration,
    super.key,
  });

  @override
  State<AnimatedElevatedCard> createState() => _AnimatedElevatedCardState();
}

class _AnimatedElevatedCardState extends State<AnimatedElevatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? AnimationDuration.hoverEffect,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    _controller.forward();
  }

  void _onExit() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final elevation = 2.0 + (_controller.value * 6.0);
            final shadowColor = Color.fromRGBO(
              0,
              0,
              0,
              0.1 + (_controller.value * 0.1),
            );

            return Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.card),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: elevation * 2,
                    offset: Offset(0, elevation),
                  ),
                ],
              ),
              padding: widget.padding,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
