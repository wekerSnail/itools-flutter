import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';
import '../domain/folder_mapping.dart';

class FolderMappingStore {
  static const _path = 'folder_mapping/collections.json';
  final _store = FileStore();

  Future<List<FolderCollection>> load() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint(
        '[FolderMappingStore] collections.json is corrupted, reset to empty: $e',
      );
      return [];
    }

    final collections = <FolderCollection>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        collections.add(FolderCollection.fromJson(entry));
      } catch (e) {
        // 单条脏数据跳过，不影响其余集合加载。
        debugPrint('[FolderMappingStore] Skip corrupted entry: $e');
      }
    }
    return collections;
  }

  Future<void> save(List<FolderCollection> collections) async {
    final encoded = jsonEncode(
      collections.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
