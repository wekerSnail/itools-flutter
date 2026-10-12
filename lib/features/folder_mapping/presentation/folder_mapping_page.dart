import 'dart:io';

import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/custom_show_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../application/collection_editor_dialog.dart';
import '../application/folder_opener.dart';
import '../application/shortcut_editor_dialog.dart';
import '../data/folder_mapping_store.dart';
import '../domain/folder_mapping.dart';
import 'widgets/collection_panel.dart';
import 'widgets/shortcuts_panel.dart';

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

  Future<void> _createOrEditCollection({FolderCollection? original}) async {
    final result = await showCollectionEditorDialog(
      context: context,
      original: original,
    );
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
    final confirmed = await showConfirmDialog(
      context: context,
      title: '确认删除集合',
      content: '确定要删除集合"${collection.name}"吗？此操作不可撤销。',
      confirmText: '确定删除',
      isDestructive: true,
    );
    if (confirmed != true) return;

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

    final result = await showShortcutEditorDialog(
      context: context,
      original: original,
    );
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

    final confirmed = await showConfirmDialog(
      context: context,
      title: '确认删除快捷方式',
      content: '确定要删除快捷方式"${shortcut.name}"吗？此操作不可撤销。',
      confirmText: '确定删除',
      isDestructive: true,
    );
    if (confirmed != true) return;

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

  Future<void> _openFolder(FolderShortcut shortcut) async {
    final path = shortcut.targetPath;
    // 异步判断：网络盘/慢速路径下同步 IO 会阻塞 UI 线程。
    if (!await Directory(path).exists()) {
      _showToast('目录不存在：$path');
      return;
    }
    await _opener.open(path);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '文件夹快捷方式',
        actions: [
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () => _createOrEditCollection(),
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
        children: [
          CollectionPanel(
            collections: _collections,
            selectedId: _selectedCollection?.id,
            onSelect: (item) => setState(() => _selectedCollection = item),
            onCreate: () => _createOrEditCollection(),
            onEdit: (item) => _createOrEditCollection(original: item),
            onDelete: _removeCollection,
            onReorder: _reorderCollections,
          ),
          ShortcutsPanel(
            collection: _selectedCollection,
            onAdd: () => _createOrEditShortcut(),
            onEdit: (item) => _createOrEditShortcut(original: item),
            onDelete: _removeShortcut,
            onOpen: _openFolder,
            onReorder: _reorderShortcuts,
          ),
        ],
      ),
    );
  }
}
