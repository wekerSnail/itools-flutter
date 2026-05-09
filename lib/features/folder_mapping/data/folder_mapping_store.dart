import 'dart:convert';

import '../../../core/data/file_store.dart';
import '../domain/folder_mapping.dart';

class FolderMappingStore {
  static const _path = 'folder_mapping/collections.json';
  final _store = FileStore();

  Future<List<FolderCollection>> load() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => FolderCollection.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(List<FolderCollection> collections) async {
    final encoded = jsonEncode(
      collections.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
