import 'package:flutter/foundation.dart';

import '../domain/hotkey_action_descriptor.dart';

class HotkeyActionRegistry {
  HotkeyActionRegistry._();

  static final HotkeyActionRegistry instance = HotkeyActionRegistry._();

  final List<HotkeyActionDescriptor> _actions = [];

  List<HotkeyActionDescriptor> get actions => List.unmodifiable(_actions);

  void register(HotkeyActionDescriptor action) {
    final existingIndex = _actions.indexWhere((a) => a.id == action.id);
    if (existingIndex >= 0) {
      _actions[existingIndex] = action;
      debugPrint('[HotkeyActionRegistry] Updated action: ${action.id}');
    } else {
      _actions.add(action);
      debugPrint('[HotkeyActionRegistry] Registered action: ${action.id}');
    }
  }

  void unregister(String actionId) {
    _actions.removeWhere((a) => a.id == actionId);
    debugPrint('[HotkeyActionRegistry] Unregistered action: $actionId');
  }

  HotkeyActionDescriptor? findById(String actionId) {
    return _actions.where((a) => a.id == actionId).firstOrNull;
  }
}
