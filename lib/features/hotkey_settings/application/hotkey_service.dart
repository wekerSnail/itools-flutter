import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../data/hotkey_action_registry.dart';
import '../domain/hotkey_config.dart';

class HotkeyService {
  HotkeyService._();

  static Future<void> registerAllHotkeys(
    List<HotkeyConfig> configs,
    HotkeyActionRegistry registry,
  ) async {
    await hotKeyManager.unregisterAll();

    final seenSignatures = <String>{};
    for (final config in configs) {
      if (!config.enabled) continue;

      final action = registry.findById(config.actionId);
      if (action == null) {
        debugPrint('[HotkeyService] Action not found: ${config.actionId}');
        continue;
      }

      // 注册期冲突：后写覆盖先写（与保存期确认框互补）。
      final signature = config.signature;
      if (!seenSignatures.add(signature)) {
        debugPrint(
          '[HotkeyService] Duplicate hotkey ${config.displayText}, '
          'skip ${config.actionId}',
        );
        continue;
      }

      await _registerHotkey(config, action.onTrigger);
    }
  }

  /// 将旧配置中的 key 标签迁移为 usbHidUsage（一次性，调用方负责持久化）。
  static HotkeyConfig migrateKeyId(HotkeyConfig config) {
    if (config.keyId != null || config.key.isEmpty) {
      return config;
    }
    final physicalKey = parsePhysicalKey(config.key);
    if (physicalKey == null) {
      return config;
    }
    return config.copyWith(keyId: physicalKey.usbHidUsage);
  }

  static Future<void> _registerHotkey(
    HotkeyConfig config,
    VoidCallback onTrigger,
  ) async {
    final physicalKey = resolvePhysicalKey(config);
    if (physicalKey == null) {
      // 无法识别的按键（如小键盘数字、符号键）直接跳过，
      // 避免静默回退成 A 键导致 UI 显示与实际热键不符。
      debugPrint(
        '[HotkeyService] Unsupported key "${config.key}", '
        'skip registering ${config.actionId}',
      );
      return;
    }

    final modifiers = <HotKeyModifier>[];
    for (final name in config.modifiers) {
      final modifier = _parseModifier(name);
      if (modifier == null) {
        debugPrint(
          '[HotkeyService] Unknown modifier "$name", '
          'skip registering ${config.actionId}',
        );
        return;
      }
      modifiers.add(modifier);
    }

    try {
      final hotKey = HotKey(key: physicalKey, modifiers: modifiers);

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

  /// 优先用持久化的 usbHidUsage；旧配置回退 key 标签解析。
  static PhysicalKeyboardKey? resolvePhysicalKey(HotkeyConfig config) {
    final keyId = config.keyId;
    if (keyId != null) {
      return PhysicalKeyboardKey(keyId);
    }
    return parsePhysicalKey(config.key);
  }

  static PhysicalKeyboardKey? parsePhysicalKey(String key) {
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
      return null;
    }

    // Single character keys
    if (upperKey.length == 1) {
      final code = upperKey.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        // A-Z → HID usage 0x070004..
        return PhysicalKeyboardKey(code + 0x00070000 - 65 + 4);
      }
      if (code >= 48 && code <= 57) {
        // 0-9 → HID usage 0x07001E..
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
        return null;
    }
  }

  /// 未知 modifier 返回 null（不再静默回退 control）。
  static HotKeyModifier? _parseModifier(String modifier) {
    switch (modifier.toLowerCase()) {
      case 'ctrl':
      case 'control':
        return HotKeyModifier.control;
      case 'shift':
        return HotKeyModifier.shift;
      case 'alt':
        return HotKeyModifier.alt;
      case 'meta':
        return HotKeyModifier.meta;
      default:
        return null;
    }
  }
}
