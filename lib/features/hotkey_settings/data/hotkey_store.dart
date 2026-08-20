import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';
import '../domain/hotkey_config.dart';

class HotkeyStore {
  static const _path = 'settings/hotkeys.json';
  final _store = FileStore();

  Future<List<HotkeyConfig>> loadConfigs() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('[HotkeyStore] hotkeys.json is corrupted, reset to empty: $e');
      return [];
    }

    final configs = <HotkeyConfig>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        configs.add(HotkeyConfig.fromJson(entry));
      } catch (e) {
        // 单条脏数据跳过，不影响其余热键配置加载。
        debugPrint('[HotkeyStore] Skip corrupted config entry: $e');
      }
    }
    return configs;
  }

  Future<void> saveConfigs(List<HotkeyConfig> configs) async {
    final encoded = jsonEncode(
      configs.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
