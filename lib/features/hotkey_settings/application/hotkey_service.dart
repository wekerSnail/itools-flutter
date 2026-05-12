import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../data/hotkey_action_registry.dart';
import '../data/hotkey_store.dart';
import '../domain/hotkey_config.dart';

class HotkeyService {
  HotkeyService._();

  static final HotkeyService instance = HotkeyService._();

  final HotkeyStore _store = HotkeyStore();
  final List<HotkeyConfig> _configs = [];
  bool _initialized = false;

  List<HotkeyConfig> get configs => List.unmodifiable(_configs);

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[HotkeyService] Already initialized, skipping');
      return;
    }

    debugPrint('[HotkeyService] Initializing...');
    await _loadConfigs();
    await _registerAllHotkeys();
    _initialized = true;
    debugPrint('[HotkeyService] Initialized with ${_configs.length} configs');
  }

  Future<void> _loadConfigs() async {
    try {
      final loaded = await _store.loadConfigs();
      _configs
        ..clear()
        ..addAll(loaded);
      debugPrint('[HotkeyService] Loaded ${_configs.length} configs');
    } catch (e) {
      debugPrint('[HotkeyService] Failed to load configs: $e');
    }
  }

  Future<void> _registerAllHotkeys() async {
    await hotKeyManager.unregisterAll();

    for (final config in _configs) {
      if (!config.enabled) continue;

      final action = HotkeyActionRegistry.instance.findById(config.actionId);
      if (action == null) {
        debugPrint('[HotkeyService] Action not found: ${config.actionId}');
        continue;
      }

      await _registerHotkey(config, action.onTrigger);
    }
  }

  Future<void> _registerHotkey(
    HotkeyConfig config,
    VoidCallback onTrigger,
  ) async {
    try {
      final hotKey = HotKey(
        key: _parsePhysicalKey(config.key),
        modifiers: config.modifiers.map(_parseModifier).toList(),
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) => onTrigger(),
      );

      debugPrint('[HotkeyService] Registered hotkey: ${config.displayText}');
    } catch (e) {
      debugPrint(
        '[HotkeyService] Failed to register hotkey ${config.displayText}: $e',
      );
    }
  }

  PhysicalKeyboardKey _parsePhysicalKey(String key) {
    final upperKey = key.toUpperCase();

    // Function keys
    if (upperKey.startsWith('F') && upperKey.length <= 3) {
      final num = int.tryParse(upperKey.substring(1));
      if (num != null && num >= 1 && num <= 12) {
        switch (num) {
          case 1:
            return PhysicalKeyboardKey.f1;
          case 2:
            return PhysicalKeyboardKey.f2;
          case 3:
            return PhysicalKeyboardKey.f3;
          case 4:
            return PhysicalKeyboardKey.f4;
          case 5:
            return PhysicalKeyboardKey.f5;
          case 6:
            return PhysicalKeyboardKey.f6;
          case 7:
            return PhysicalKeyboardKey.f7;
          case 8:
            return PhysicalKeyboardKey.f8;
          case 9:
            return PhysicalKeyboardKey.f9;
          case 10:
            return PhysicalKeyboardKey.f10;
          case 11:
            return PhysicalKeyboardKey.f11;
          case 12:
            return PhysicalKeyboardKey.f12;
        }
      }
    }

    // Single character keys
    if (upperKey.length == 1) {
      final code = upperKey.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        // A-Z
        return PhysicalKeyboardKey(code + 0x00070000 - 65 + 4);
      }
      if (code >= 48 && code <= 57) {
        // 0-9
        return PhysicalKeyboardKey(code + 0x00070000 - 48 + 0x1E);
      }
    }

    // Special keys
    switch (upperKey) {
      case 'SPACE':
        return PhysicalKeyboardKey.space;
      case 'ENTER':
        return PhysicalKeyboardKey.enter;
      case 'TAB':
        return PhysicalKeyboardKey.tab;
      case 'ESCAPE':
        return PhysicalKeyboardKey.escape;
      case 'BACKSPACE':
        return PhysicalKeyboardKey.backspace;
      case 'DELETE':
        return PhysicalKeyboardKey.delete;
      case 'INSERT':
        return PhysicalKeyboardKey.insert;
      case 'HOME':
        return PhysicalKeyboardKey.home;
      case 'END':
        return PhysicalKeyboardKey.end;
      case 'PAGEUP':
        return PhysicalKeyboardKey.pageUp;
      case 'PAGEDOWN':
        return PhysicalKeyboardKey.pageDown;
      case 'ARROWUP':
        return PhysicalKeyboardKey.arrowUp;
      case 'ARROWDOWN':
        return PhysicalKeyboardKey.arrowDown;
      case 'ARROWLEFT':
        return PhysicalKeyboardKey.arrowLeft;
      case 'ARROWRIGHT':
        return PhysicalKeyboardKey.arrowRight;
      default:
        return PhysicalKeyboardKey.keyA;
    }
  }

  HotKeyModifier _parseModifier(String modifier) {
    switch (modifier.toLowerCase()) {
      case 'ctrl':
        return HotKeyModifier.control;
      case 'shift':
        return HotKeyModifier.shift;
      case 'alt':
        return HotKeyModifier.alt;
      case 'meta':
        return HotKeyModifier.meta;
      default:
        return HotKeyModifier.control;
    }
  }

  Future<void> updateConfig(HotkeyConfig config) async {
    final index = _configs.indexWhere((c) => c.actionId == config.actionId);
    if (index >= 0) {
      _configs[index] = config;
    } else {
      _configs.add(config);
    }

    await _store.saveConfigs(_configs);
    await _registerAllHotkeys();
  }

  Future<void> removeConfig(String actionId) async {
    _configs.removeWhere((c) => c.actionId == actionId);
    await _store.saveConfigs(_configs);
    await _registerAllHotkeys();
  }

  HotkeyConfig? getConfig(String actionId) {
    return _configs.where((c) => c.actionId == actionId).firstOrNull;
  }

  Future<void> reload() async {
    await _loadConfigs();
    await _registerAllHotkeys();
  }
}
