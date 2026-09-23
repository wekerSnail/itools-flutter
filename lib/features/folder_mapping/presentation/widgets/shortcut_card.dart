import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_tokens/index.dart';
import '../../../../core/widgets/surface_cards.dart';
import '../../domain/folder_mapping.dart';

/// Draggable shortcut row card with hover actions and context menu.
class ShortcutCard extends StatefulWidget {
  const ShortcutCard({
    required this.item,
    required this.index,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final FolderShortcut item;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: InteractiveSurfaceCard(
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 15,
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: shad.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
                  ),
                  child: Icon(
                    LucideIcons.link,
                    size: 18,
                    color: shad.colorScheme.secondaryForeground,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: Typography.body.copyWith(
                          color: shad.colorScheme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.targetPath,
                        style: Typography.caption.copyWith(
                          color: shad.colorScheme.mutedForeground,
                          fontFamily: 'Consolas',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                if (_hovered) ...[
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: widget.onOpen,
                    child: const Icon(LucideIcons.folderOpen, size: 14),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: widget.onEdit,
                    child: const Icon(LucideIcons.pencil, size: 14),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: widget.onDelete,
                    child: Icon(
                      LucideIcons.trash2,
                      size: 14,
                      color: shad.colorScheme.destructive,
                    ),
                  ),
                ] else
                  ShadContextMenu(
                    items: [
                      ShadContextMenuItem(
                        onPressed: widget.onOpen,
                        child: const Text('打开目录'),
                      ),
                      ShadContextMenuItem(
                        onPressed: widget.onEdit,
                        child: const Text('编辑快捷方式'),
                      ),
                      ShadContextMenuItem(
                        onPressed: widget.onDelete,
                        child: const Text('删除快捷方式'),
                      ),
                    ],
                    child: Icon(
                      LucideIcons.ellipsis,
                      size: 16,
                      color: shad.colorScheme.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
