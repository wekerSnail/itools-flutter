import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../tools/tool_descriptor.dart';

class WindowManagerService {
  WindowManagerService._() {
    _listenForWindowChanges();
  }

  static final WindowManagerService instance = WindowManagerService._();

  final Map<String, String> _openWindowIds = {};

  bool isToolWindowOpen(String toolId) {
    return _openWindowIds.containsKey(toolId);
  }

  void _listenForWindowChanges() {
    onWindowsChanged.listen((_) async {
      try {
        final windows = await WindowController.getAll();
        final activeIds = windows.map((w) => w.windowId).toSet();
        final toRemove = <String>[];
        for (final entry in _openWindowIds.entries) {
          if (!activeIds.contains(entry.value)) {
            toRemove.add(entry.key);
          }
        }
        for (final key in toRemove) {
          _openWindowIds.remove(key);
          debugPrint('[WindowManager] Window closed: $key');
        }
      } catch (_) {}
    });
  }

  Future<void> openToolWindow(ToolDescriptor tool) async {
    if (_openWindowIds.containsKey(tool.id)) {
      final existingId = _openWindowIds[tool.id]!;
      try {
        final controller = WindowController.fromWindowId(existingId);
        await controller.show();
        return;
      } catch (_) {
        _openWindowIds.remove(tool.id);
      }
    }

    final controller = await WindowController.create(
      WindowConfiguration(arguments: tool.id),
    );

    _openWindowIds[tool.id] = controller.windowId;
    debugPrint(
      '[WindowManager] Opened window for ${tool.id}: ${controller.windowId}',
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await controller.show();
  }

  static String? decodeToolId(String? args) {
    if (args == null || args.isEmpty) return null;
    return args;
  }
}
