import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// Menu item model for [PopupMenuAnchor].
///
/// Named [PopupMenuAction] (not `PopupMenuItem`) to avoid clashing with
/// Material's `PopupMenuItem` / `PopupMenuEntry`.
class PopupMenuAction {
  const PopupMenuAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

/// Lightweight overlay-based popup menu trigger.
///
/// Anchors [child]; pointer-down opens a [PopupMenuOverlay] near the child.
class PopupMenuAnchor extends StatefulWidget {
  const PopupMenuAnchor({
    required this.items,
    required this.child,
    super.key,
  });

  final List<PopupMenuAction> items;
  final Widget child;

  @override
  State<PopupMenuAnchor> createState() => _PopupMenuAnchorState();
}

class _PopupMenuAnchorState extends State<PopupMenuAnchor> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showMenu() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => PopupMenuOverlay(
        items: widget.items,
        layerLink: _layerLink,
        onDismiss: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Listener(
        onPointerDown: (event) {
          _showMenu();
        },
        child: widget.child,
      ),
    );
  }
}

/// Positioned menu surface shown by [PopupMenuAnchor].
class PopupMenuOverlay extends StatelessWidget {
  const PopupMenuOverlay({
    required this.items,
    required this.layerLink,
    required this.onDismiss,
    super.key,
  });

  final List<PopupMenuAction> items;
  final LayerLink layerLink;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-100, 25),
          child: IntrinsicWidth(
            child: Container(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 150),
              decoration: BoxDecoration(
                color: shad.colorScheme.card,
                border: Border.all(color: shad.colorScheme.border),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                boxShadow: Shadows.md,
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  return GestureDetector(
                    onTap: () {
                      onDismiss();
                      item.onTap();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xs,
                      ),
                      child: Text(
                        item.label,
                        style: Typography.bodySmall.copyWith(
                          color: shad.colorScheme.foreground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
