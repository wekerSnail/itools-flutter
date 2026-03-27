import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/folder_mapping.dart';

class FolderMappingStore {
  static const _key = 'folder.mapping.v2';
  static const _legacyKey = 'folder.mapping.v1';

  Future<List<FolderCollection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => FolderCollection.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    final legacyRaw = prefs.getString(_legacyKey);
    if (legacyRaw == null || legacyRaw.isEmpty) {
      return [];
    }

    final legacyDecoded = jsonDecode(legacyRaw) as List<dynamic>;
    final legacyMappings = legacyDecoded
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);

    final migrated = <FolderCollection>[
      FolderCollection(
        id: 'default_collection',
        name: '默认集合',
        createdAt: DateTime.now(),
        items: legacyMappings
            .map(
              (e) => FolderShortcut(
                id:
                    e['id']?.toString() ??
                    '${DateTime.now().millisecondsSinceEpoch}_${e.hashCode}',
                name: e['name']?.toString() ?? '未命名快捷方式',
                targetPath: e['targetPath']?.toString() ?? '',
                createdAt:
                    DateTime.tryParse(e['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            )
            .where((e) => e.targetPath.isNotEmpty)
            .toList(growable: false),
      ),
    ];

    await save(migrated);
    return migrated;
  }

  Future<void> save(List<FolderCollection> collections) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      collections.map((e) => e.toJson()).toList(growable: false),
    );
    await prefs.setString(_key, encoded);
  }
}
