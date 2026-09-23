import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_tokens/index.dart';
import '../../domain/folder_mapping.dart';
import 'shortcut_card.dart';

/// Right-side shortcuts panel for the selected collection.
class ShortcutsPanel extends StatelessWidget {
  const ShortcutsPanel({
    required this.collection,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
    required this.onReorder,
    super.key,
  });

  final FolderCollection? collection;
  final VoidCallback onAdd;
  final ValueChanged<FolderShortcut> onEdit;
  final ValueChanged<FolderShortcut> onDelete;
  final ValueChanged<FolderShortcut> onOpen;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final collection = this.collection;

    if (collection == null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.folderOpen,
                size: 40,
                color: shad.colorScheme.mutedForeground,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '请先在左侧创建并选择一个集合',
                style: Typography.bodySmall.copyWith(
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.folder,
                  size: 16,
                  color: shad.colorScheme.foreground,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  collection.name,
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                ShadBadge.secondary(child: Text('${collection.items.length}')),
                const Spacer(),
                Text(
                  '双击可打开，拖拽手柄可排序',
                  style: Typography.caption.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: onAdd,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14),
                      SizedBox(width: Spacing.xs),
                      Text('新增快捷方式'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: shad.colorScheme.border),
          Expanded(
            child: collection.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.link,
                          size: 36,
                          color: shad.colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '此集合暂无快捷方式',
                          style: Typography.bodySmall.copyWith(
                            color: shad.colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: onAdd,
                          child: const Text('创建快捷方式'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(Spacing.sm),
                    buildDefaultDragHandles: false,
                    itemCount: collection.items.length,
                    onReorder: onReorder,
                    itemBuilder: (_, index) {
                      final item = collection.items[index];
                      return ShortcutCard(
                        key: ValueKey<String>(item.id),
                        item: item,
                        index: index,
                        onOpen: () => onOpen(item),
                        onEdit: () => onEdit(item),
                        onDelete: () => onDelete(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
