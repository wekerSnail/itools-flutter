import 'dart:async';

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
///
/// [index] 越大入场越晚；[staggerDuration] 指定单次入场动画时长
/// （步进间隔固定使用 [AnimationDuration.stagger]）。
class StaggeredAnimationBuilder extends StatefulWidget {
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
  State<StaggeredAnimationBuilder> createState() =>
      _StaggeredAnimationBuilderState();
}

class _StaggeredAnimationBuilderState extends State<StaggeredAnimationBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.staggerDuration ?? AnimationDuration.pageTransition,
    );
    final step = AnimationDuration.stagger == Duration.zero
        ? const Duration(milliseconds: 40)
        : AnimationDuration.stagger;
    final delay = step * widget.index;
    if (delay <= Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
