import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_tokens/index.dart';
import '../../../../core/widgets/popup_menu.dart';
import '../../../../core/widgets/surface_cards.dart';
import '../../domain/folder_mapping.dart';

/// Left-side collection list panel with reorder and per-item menu.
class CollectionPanel extends StatelessWidget {
  const CollectionPanel({
    required this.collections,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    super.key,
  });

  final List<FolderCollection> collections;
  final String? selectedId;
  final ValueChanged<FolderCollection> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<FolderCollection> onEdit;
  final ValueChanged<FolderCollection> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: shad.colorScheme.background,
        border: Border(right: BorderSide(color: shad.colorScheme.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            child: PageSectionHeader(
              title: '集合管理',
              subtitle: '把目录集合集中管理，再在右侧维护每个集合下的快捷方式。',
              icon: LucideIcons.folders,
              trailing: ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: onCreate,
                child: const Icon(LucideIcons.plus, size: 15),
              ),
            ),
          ),
          Container(height: 1, color: shad.colorScheme.border),
          Expanded(
            child: collections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.folderX,
                          size: 32,
                          color: shad.colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '暂无集合',
                          style: Typography.bodySmall.copyWith(
                            color: shad.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    buildDefaultDragHandles: false,
                    itemCount: collections.length,
                    onReorder: onReorder,
                    itemBuilder: (_, index) {
                      final item = collections[index];
                      final selected = selectedId == item.id;
                      return Container(
                        key: ValueKey<String>(item.id),
                        margin: const EdgeInsets.symmetric(
                          horizontal: Spacing.xs,
                          vertical: 2,
                        ),
                        child: GestureDetector(
                          onTap: () => onSelect(item),
                          child: AnimatedContainer(
                            duration: AnimationDuration.hoverEffect,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                              vertical: Spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? shad.colorScheme.accent
                                  : shad.colorScheme.background,
                              borderRadius: BorderRadius.circular(
                                BorderRadiusTokens.sm,
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(
                                    LucideIcons.gripVertical,
                                    size: 15,
                                    color: shad.colorScheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Icon(
                                  LucideIcons.folder,
                                  size: 16,
                                  color: selected
                                      ? shad.colorScheme.accentForeground
                                      : shad.colorScheme.mutedForeground,
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Typography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? shad
                                                    .colorScheme
                                                    .accentForeground
                                              : shad.colorScheme.foreground,
                                        ),
                                      ),
                                      Text(
                                        '${item.items.length} 个快捷方式',
                                        style: Typography.caption.copyWith(
                                          color: shad
                                              .colorScheme
                                              .mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuAnchor(
                                  items: [
                                    PopupMenuAction(
                                      label: '编辑集合',
                                      onTap: () => onEdit(item),
                                    ),
                                    PopupMenuAction(
                                      label: '删除集合',
                                      onTap: () => onDelete(item),
                                    ),
                                  ],
                                  child: Icon(
                                    LucideIcons.ellipsis,
                                    size: 15,
                                    color: shad.colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
