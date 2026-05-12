import 'dart:convert';

import '../../../core/data/file_store.dart';
import '../domain/hotkey_config.dart';

class HotkeyStore {
  static const _path = 'settings/hotkeys.json';
  final _store = FileStore();

  Future<List<HotkeyConfig>> loadConfigs() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => HotkeyConfig.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveConfigs(List<HotkeyConfig> configs) async {
    final encoded = jsonEncode(
      configs.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
