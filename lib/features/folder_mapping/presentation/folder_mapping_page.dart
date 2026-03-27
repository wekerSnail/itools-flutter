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

  final List<FolderMapping> _mappings = <FolderMapping>[];
  FolderMapping? _selected;

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
      _mappings
        ..clear()
        ..addAll(loaded);
      _selected = _mappings.isEmpty ? null : _mappings.first;
    });
  }

  Future<void> _persist() => _store.save(_mappings);

  Future<void> _createOrEdit({FolderMapping? original}) async {
    final nameCtrl = TextEditingController(text: original?.name ?? '');
    final sourceCtrl = TextEditingController(text: original?.sourcePath ?? '');
    final targetCtrl = TextEditingController(text: original?.targetPath ?? '');

    Future<void> pick(TextEditingController ctrl) async {
      final path = await getDirectoryPath(confirmButtonText: '选择');
      if (path != null) {
        ctrl.text = path;
      }
    }

    final result = await showDialog<FolderMapping>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(original == null ? '新增映射' : '编辑映射'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '映射名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sourceCtrl,
                        decoration: const InputDecoration(
                          labelText: '源目录',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => pick(sourceCtrl),
                      icon: const Icon(Icons.folder_open),
                      tooltip: '选择目录',
                    ),
                  ],
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
                      onPressed: () => pick(targetCtrl),
                      icon: const Icon(Icons.folder_open),
                      tooltip: '选择目录',
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
                if (nameCtrl.text.trim().isEmpty ||
                    sourceCtrl.text.trim().isEmpty ||
                    targetCtrl.text.trim().isEmpty) {
                  return;
                }

                Navigator.of(context).pop(
                  FolderMapping(
                    id:
                        original?.id ??
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
                    name: nameCtrl.text.trim(),
                    sourcePath: sourceCtrl.text.trim(),
                    targetPath: targetCtrl.text.trim(),
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
    sourceCtrl.dispose();
    targetCtrl.dispose();

    if (result == null) {
      return;
    }

    setState(() {
      final idx = _mappings.indexWhere((e) => e.id == result.id);
      if (idx >= 0) {
        _mappings[idx] = result;
      } else {
        _mappings.add(result);
      }
      _selected = result;
    });
    await _persist();
  }

  Future<void> _remove(FolderMapping mapping) async {
    setState(() {
      _mappings.removeWhere((e) => e.id == mapping.id);
      if (_selected?.id == mapping.id) {
        _selected = _mappings.isEmpty ? null : _mappings.first;
      }
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

  Widget _buildFolderTile(String title, String path) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(path),
        leading: const Icon(Icons.folder_outlined),
        onTap: () => _openFolder(path),
        onLongPress: () => _openFolder(path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件夹映射'),
        actions: [
          IconButton(
            tooltip: '新增映射',
            onPressed: () => _createOrEdit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                ListTile(
                  title: const Text('映射列表'),
                  trailing: IconButton(
                    onPressed: () => _createOrEdit(),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _mappings.length,
                    itemBuilder: (_, index) {
                      final item = _mappings[index];
                      final selected = _selected?.id == item.id;
                      return InkWell(
                        onTap: () => setState(() => _selected = item),
                        onDoubleTap: () => _openFolder(item.targetPath),
                        child: Container(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder_special_outlined),
                            title: Text(item.name),
                            subtitle: Text(
                              item.targetPath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _createOrEdit(original: item);
                                  return;
                                }
                                if (value == 'delete') {
                                  await _remove(item);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
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
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected == null
                ? const Center(child: Text('暂无映射，请点击左上角 + 创建'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _selected!.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      _buildFolderTile('源目录（单击打开）', _selected!.sourcePath),
                      _buildFolderTile('目标目录（单击打开）', _selected!.targetPath),
                      const SizedBox(height: 8),
                      const Text('提示：左侧列表双击条目可直接打开目标目录。'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
