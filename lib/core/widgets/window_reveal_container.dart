import 'package:flutter/widgets.dart';

import '../system/window_reveal_controller.dart';

class WindowRevealContainer extends StatefulWidget {
  const WindowRevealContainer({
    required this.child,
    super.key,
    this.controller,
    this.enabled = true,
  });

  final Widget child;
  final WindowRevealController? controller;
  final bool enabled;

  @override
  State<WindowRevealContainer> createState() => _WindowRevealContainerState();
}

class _WindowRevealContainerState extends State<WindowRevealContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;
  late final WindowRevealController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? WindowRevealController.instance;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _controller.addListener(_handleReveal);

    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _playReveal();
        }
      });
    } else {
      _animationController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant WindowRevealContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled && !widget.enabled) {
      _animationController.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleReveal);
    _animationController.dispose();
    super.dispose();
  }

  void _handleReveal() {
    if (!mounted || !widget.enabled) {
      return;
    }
    _playReveal();
  }

  void _playReveal() {
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
