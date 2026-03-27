import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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
    if (!mounted) {
      return;
    }

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
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  Future<void> _createOrEditCollection({FolderCollection? original}) async {
    final nameCtrl = TextEditingController(text: original?.name ?? '');

    final result = await showDialog<FolderCollection>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(original == null ? '新增集合' : '编辑集合'),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '集合名称',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  return;
                }

                Navigator.of(context).pop(
                  FolderCollection(
                    id:
                        original?.id ??
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
                    name: name,
                    items: original?.items ?? <FolderShortcut>[],
                    createdAt: original?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();

    if (result == null) {
      return;
    }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建并选择一个集合')));
      return;
    }

    final nameCtrl = TextEditingController(text: original?.name ?? '');
    final targetCtrl = TextEditingController(text: original?.targetPath ?? '');

    Future<void> pickTarget() async {
      final path = await getDirectoryPath(confirmButtonText: '选择目标目录');
      if (path != null) {
        targetCtrl.text = path;
      }
    }

    final result = await showDialog<FolderShortcut>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(original == null ? '新增快捷方式' : '编辑快捷方式'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '快捷方式名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: targetCtrl,
                        decoration: const InputDecoration(
                          labelText: '目标目录',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: pickTarget,
                      icon: const Icon(Icons.folder_open),
                      tooltip: '选择目标目录',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final target = targetCtrl.text.trim();
                if (name.isEmpty || target.isEmpty) {
                  return;
                }

                Navigator.of(context).pop(
                  FolderShortcut(
                    id:
                        original?.id ??
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
                    name: name,
                    targetPath: target,
                    createdAt: original?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    targetCtrl.dispose();

    if (result == null) {
      return;
    }

    setState(() {
      final cIndex = _collections.indexWhere((e) => e.id == collection.id);
      if (cIndex < 0) {
        return;
      }

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
    if (collection == null) {
      return;
    }

    setState(() {
      final cIndex = _collections.indexWhere((e) => e.id == collection.id);
      if (cIndex < 0) {
        return;
      }
      final items = List<FolderShortcut>.from(_collections[cIndex].items)
        ..removeWhere((e) => e.id == shortcut.id);
      _collections[cIndex] = _collections[cIndex].copyWith(items: items);
      _selectedCollection = _collections[cIndex];
    });
    await _persist();
  }

  Future<void> _openFolder(String path) async {
    if (!Directory(path).existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('目录不存在：$path')));
      return;
    }

    await _opener.open(path);
  }

  @override
  Widget build(BuildContext context) {
    final collection = _selectedCollection;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件夹快捷方式'),
        actions: [
          IconButton(
            tooltip: '新增集合',
            onPressed: () => _createOrEditCollection(),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '新增快捷方式',
            onPressed: () => _createOrEditShortcut(),
            icon: const Icon(Icons.add_link_outlined),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Column(
              children: [
                ListTile(
                  title: const Text('集合列表'),
                  trailing: IconButton(
                    onPressed: () => _createOrEditCollection(),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _collections.isEmpty
                      ? const Center(child: Text('暂无集合'))
                      : ListView.builder(
                          itemCount: _collections.length,
                          itemBuilder: (_, index) {
                            final item = _collections[index];
                            final selected = _selectedCollection?.id == item.id;
                            return Container(
                              color: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.folder_special_outlined,
                                ),
                                title: Text(item.name),
                                subtitle: Text('${item.items.length} 个快捷方式'),
                                onTap: () {
                                  setState(() => _selectedCollection = item);
                                },
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _createOrEditCollection(
                                        original: item,
                                      );
                                      return;
                                    }
                                    if (value == 'delete') {
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
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: collection == null
                ? const Center(child: Text('请先在左侧创建并选择一个集合'))
                : Column(
                    children: [
                      ListTile(
                        title: Text(
                          '集合：${collection.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: const Text('双击可直接打开目标目录'),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => _createOrEditShortcut(),
                          icon: const Icon(Icons.add),
                          label: const Text('新增快捷方式'),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: collection.items.isEmpty
                            ? const Center(
                                child: Text('此集合暂无快捷方式，点击“新增快捷方式”创建'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: collection.items.length,
                                itemBuilder: (_, index) {
                                  final item = collection.items[index];
                                  return Card(
                                    child: InkWell(
                                      onTap: () => _openFolder(item.targetPath),
                                      onDoubleTap: () =>
                                          _openFolder(item.targetPath),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.shortcut_outlined,
                                        ),
                                        title: Text(item.name),
                                        subtitle: Text(
                                          item.targetPath,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'open') {
                                              await _openFolder(
                                                item.targetPath,
                                              );
                                              return;
                                            }
                                            if (value == 'edit') {
                                              await _createOrEditShortcut(
                                                original: item,
                                              );
                                              return;
                                            }
                                            if (value == 'delete') {
                                              await _removeShortcut(item);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'open',
                                              child: Text('打开目录'),
                                            ),
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('编辑快捷方式'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('删除快捷方式'),
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
          ),
        ],
      ),
    );
  }
}
