import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../tools/tool_descriptor.dart';

class WindowManagerService {
  WindowManagerService._() {
    _listenForWindowChanges();
  }

  static final WindowManagerService instance = WindowManagerService._();

  final Map<String, List<String>> _openWindowIds = {};

  bool isToolWindowOpen(String toolId) {
    final ids = _openWindowIds[toolId];
    return ids != null && ids.isNotEmpty;
  }

  void _listenForWindowChanges() {
    onWindowsChanged.listen((_) async {
      try {
        final windows = await WindowController.getAll();
        final activeIds = windows.map((w) => w.windowId).toSet();
        final toRemove = <String>[];
        for (final entry in _openWindowIds.entries) {
          entry.value.removeWhere((id) => !activeIds.contains(id));
          if (entry.value.isEmpty) {
            toRemove.add(entry.key);
          }
        }
        for (final key in toRemove) {
          _openWindowIds.remove(key);
          debugPrint('[WindowManager] All windows closed for: $key');
        }
      } catch (_) {}
    });
  }

  Future<void> openToolWindow(ToolDescriptor tool) async {
    final ids = _openWindowIds[tool.id];
    if (ids != null && ids.isNotEmpty) {
      try {
        final controller = WindowController.fromWindowId(ids.first);
        await controller.show();
        await controller.invokeMethod<void>('play_reveal');
        await _disposeOtherHiddenWindows(exceptToolId: tool.id);
        return;
      } catch (_) {
        _openWindowIds.remove(tool.id);
      }
    }

    final controller = await WindowController.create(
      WindowConfiguration(arguments: tool.id),
    );

    _openWindowIds[tool.id] = [controller.windowId];
    debugPrint(
      '[WindowManager] Opened window for ${tool.id}: ${controller.windowId}',
    );
    await _disposeOtherHiddenWindows(exceptToolId: tool.id);
  }

  Future<void> openNewToolWindow(ToolDescriptor tool) async {
    final controller = await WindowController.create(
      WindowConfiguration(arguments: tool.id),
    );

    _openWindowIds.putIfAbsent(tool.id, () => []).add(controller.windowId);
    debugPrint(
      '[WindowManager] Opened new window for ${tool.id}: ${controller.windowId}',
    );
  }

  Future<void> _disposeOtherHiddenWindows({
    required String exceptToolId,
  }) async {
    final entries = List<MapEntry<String, List<String>>>.from(
      _openWindowIds.entries,
    );
    for (final entry in entries) {
      if (entry.key == exceptToolId) {
        continue;
      }

      for (final windowId in List<String>.from(entry.value)) {
        try {
          final controller = WindowController.fromWindowId(windowId);
          await controller.invokeMethod<void>('dispose_if_hidden');
        } catch (_) {
          entry.value.remove(windowId);
        }
      }

      if (entry.value.isEmpty) {
        _openWindowIds.remove(entry.key);
      }
    }
  }

  static String? decodeToolId(String? args) {
    if (args == null || args.isEmpty) return null;
    return args;
  }
}
