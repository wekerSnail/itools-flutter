import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/folder_mapping.dart';

class FolderMappingStore {
  static const _key = 'folder.mapping.v1';

  Future<List<FolderMapping>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => FolderMapping.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(List<FolderMapping> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      mappings.map((e) => e.toJson()).toList(growable: false),
    );
    await prefs.setString(_key, encoded);
  }
}
