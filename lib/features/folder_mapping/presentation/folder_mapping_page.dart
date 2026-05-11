import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../application/folder_opener.dart';
import '../data/folder_mapping_store.dart';
import '../domain/folder_mapping.dart';

class FolderMappingPage extends StatefulWidget {
  const FolderMappingPage({super.key});

  @override
  State<FolderMappingPage> createState() => _FolderMappingPageState();
}

class _FolderMappingPageState extends State<FolderMappingPage> {
  final FolderMappingStore _store = FolderMappingStore();
  final FolderOpener _opener = const FolderOpener();

  final List<FolderCollection> _collections = <FolderCollection>[];
  FolderCollection? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _collections
        ..clear()
        ..addAll(loaded);
      _selectedCollection = _collections.isEmpty ? null : _collections.first;
    });
  }

  Future<void> _persist() => _store.save(_collections);

  FolderCollection? _findCollection(String id) {
    for (final c in _collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final shad = ShadTheme.of(context);
        return AlertDialog(
          backgroundColor: shad.colorScheme.background,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '确定删除',
                style: TextStyle(color: shad.colorScheme.destructive),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _createOrEditCollection({FolderCollection? original}) async {
    final nameCtrl = TextEditingController(text: original?.name ?? '');
    String? errorMsg;

    final result = await showDialog<FolderCollection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final shad = ShadTheme.of(context);
          return Dialog(
            backgroundColor: shad.colorScheme.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: SizedBox(
              width: 480,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.folderOpen,
                          size: 18,
                          color: shad.colorScheme.foreground,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          original == null ? '新增集合' : '编辑集合',
                          style: Typography.h4.copyWith(
                            color: shad.colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    ShadInput(
                      controller: nameCtrl,
                      placeholder: const Text('集合名称'),
                      autofocus: true,
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        errorMsg!,
                        style: Typography.caption.copyWith(
                          color: shad.colorScheme.destructive,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.cardPadding),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton.outline(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: Spacing.sm),
                        ShadButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setDialog(() => errorMsg = '集合名称不能为空');
                              return;
                            }
                            Navigator.of(context).pop(
                              FolderCollection(
                                id:
                                    original?.id ??
                                    '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
                                name: name,
                                items: original?.items ?? <FolderShortcut>[],
                                createdAt:
                                    original?.createdAt ?? DateTime.now(),
                              ),
                            );
                          },
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    if (result == null) return;

    setState(() {
      final idx = _collections.indexWhere((e) => e.id == result.id);
      if (idx >= 0) {
        _collections[idx] = result;
      } else {
        _collections.add(result);
      }
      _selectedCollection = _findCollection(result.id);
    });
    await _persist();
  }

  Future<void> _removeCollection(FolderCollection collection) async {
    final confirmed = await _showConfirmDialog(
      title: '确认删除集合',
      content: '确定要删除集合"${collection.name}"吗？此操作不可撤销。',
    );
    if (!confirmed) return;

    setState(() {
      _collections.removeWhere((e) => e.id == collection.id);
      if (_selectedCollection?.id == collection.id) {
        _selectedCollection = _collections.isEmpty ? null : _collections.first;
      }
    });
    await _persist();
  }

  Future<void> _createOrEditShortcut({FolderShortcut? original}) async {
    final collection = _selectedCollection;
    if (collection == null) {
      _showToast('请先创建并选择一个集合');
      return;
    }

    final nameCtrl = TextEditingController(text: original?.name ?? '');
    final targetCtrl = TextEditingController(text: original?.targetPath ?? '');
    String? errorMsg;

    final result = await showDialog<FolderShortcut>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final shad = ShadTheme.of(context);

          Future<void> pickTarget() async {
            final path = await getDirectoryPath(confirmButtonText: '选择目标目录');
            if (path != null) {
              setDialog(() => targetCtrl.text = path);
            }
          }

          return Dialog(
            backgroundColor: shad.colorScheme.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: SizedBox(
              width: 520,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.link,
                          size: 18,
                          color: shad.colorScheme.foreground,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          original == null ? '新增快捷方式' : '编辑快捷方式',
                          style: Typography.h4.copyWith(
                            color: shad.colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    ShadInput(
                      controller: nameCtrl,
                      placeholder: const Text('快捷方式名称'),
                      autofocus: true,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ShadInput(
                            controller: targetCtrl,
                            placeholder: const Text('目标目录路径'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: pickTarget,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.folderOpen, size: 14),
                              SizedBox(width: Spacing.xs),
                              Text('浏览'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        errorMsg!,
                        style: Typography.caption.copyWith(
                          color: shad.colorScheme.destructive,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.cardPadding),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton.outline(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: Spacing.sm),
                        ShadButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            final target = targetCtrl.text.trim();
                            if (name.isEmpty || target.isEmpty) {
                              setDialog(() => errorMsg = '名称和目录不能为空');
                              return;
                            }
                            Navigator.of(context).pop(
                              FolderShortcut(
                                id:
                                    original?.id ??
                                    '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
                                name: name,
                                targetPath: target,
                                createdAt:
                                    original?.createdAt ?? DateTime.now(),
                              ),
                            );
                          },
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    targetCtrl.dispose();

    if (result == null) return;

    setState(() {
      final cIndex = _collections.indexWhere((e) => e.id == collection.id);
      if (cIndex < 0) return;
      final current = _collections[cIndex];
      final items = List<FolderShortcut>.from(current.items);
      final i = items.indexWhere((e) => e.id == result.id);
      if (i >= 0) {
        items[i] = result;
      } else {
        items.add(result);
      }
      _collections[cIndex] = current.copyWith(items: items);
      _selectedCollection = _collections[cIndex];
    });
    await _persist();
  }

  Future<void> _removeShortcut(FolderShortcut shortcut) async {
    final collection = _selectedCollection;
    if (collection == null) return;

    final confirmed = await _showConfirmDialog(
      title: '确认删除快捷方式',
      content: '确定要删除快捷方式"${shortcut.name}"吗？此操作不可撤销。',
    );
    if (!confirmed) return;

    setState(() {
      final cIndex = _collections.indexWhere((e) => e.id == collection.id);
      if (cIndex < 0) return;
      final items = List<FolderShortcut>.from(_collections[cIndex].items)
        ..removeWhere((e) => e.id == shortcut.id);
      _collections[cIndex] = _collections[cIndex].copyWith(items: items);
      _selectedCollection = _collections[cIndex];
    });
    await _persist();
  }

  Future<void> _reorderCollections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _collections.removeAt(oldIndex);
      _collections.insert(newIndex, item);
      final selectedId = _selectedCollection?.id;
      _selectedCollection = selectedId == null
          ? null
          : _findCollection(selectedId);
    });

    await _persist();
  }

  Future<void> _reorderShortcuts(int oldIndex, int newIndex) async {
    final collection = _selectedCollection;
    if (collection == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final cIndex = _collections.indexWhere((e) => e.id == collection.id);
      if (cIndex < 0) return;

      final items = List<FolderShortcut>.from(_collections[cIndex].items);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _collections[cIndex] = _collections[cIndex].copyWith(items: items);
      _selectedCollection = _collections[cIndex];
    });

    await _persist();
  }

  Future<void> _openFolder(String path) async {
    if (!Directory(path).existsSync()) {
      _showToast('目录不存在：$path');
      return;
    }
    await _opener.open(path);
  }

  Widget _buildCollectionPanel(ShadThemeData shad) {
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
              icon: Icons.folder_copy_outlined,
              trailing: ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: _createOrEditCollection,
                child: const Icon(LucideIcons.plus, size: 15),
              ),
            ),
          ),
          Divider(height: 1, color: shad.colorScheme.border),
          Expanded(
            child: _collections.isEmpty
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
                    itemCount: _collections.length,
                    onReorder: _reorderCollections,
                    itemBuilder: (_, index) {
                      final item = _collections[index];
                      final selected = _selectedCollection?.id == item.id;
                      return Container(
                        key: ValueKey<String>(item.id),
                        margin: const EdgeInsets.symmetric(
                          horizontal: Spacing.xs,
                          vertical: 2,
                        ),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCollection = item),
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
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _createOrEditCollection(
                                        original: item,
                                      );
                                    } else if (value == 'delete') {
                                      await _removeCollection(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('编辑集合'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除集合'),
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

  Widget _buildShortcutsPanel(ShadThemeData shad) {
    final collection = _selectedCollection;

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
                  onPressed: _createOrEditShortcut,
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
          Divider(height: 1, color: shad.colorScheme.border),
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
                          onPressed: _createOrEditShortcut,
                          child: const Text('创建快捷方式'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(Spacing.sm),
                    buildDefaultDragHandles: false,
                    itemCount: collection.items.length,
                    onReorder: _reorderShortcuts,
                    itemBuilder: (_, index) {
                      final item = collection.items[index];
                      return _ShortcutCard(
                        key: ValueKey<String>(item.id),
                        item: item,
                        index: index,
                        onOpen: () => _openFolder(item.targetPath),
                        onEdit: () => _createOrEditShortcut(original: item),
                        onDelete: () => _removeShortcut(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '文件夹快捷方式',
        actions: [
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: _createOrEditCollection,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.folderPlus, size: 14),
                SizedBox(width: Spacing.xs),
                Text('新增集合'),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [_buildCollectionPanel(shad), _buildShortcutsPanel(shad)],
      ),
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  const _ShortcutCard({
    super.key,
    required this.item,
    required this.index,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final FolderShortcut item;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
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
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'open') {
                        widget.onOpen();
                      } else if (value == 'edit') {
                        widget.onEdit();
                      } else if (value == 'delete') {
                        widget.onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('打开目录')),
                      PopupMenuItem(value: 'edit', child: Text('编辑快捷方式')),
                      PopupMenuItem(value: 'delete', child: Text('删除快捷方式')),
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
