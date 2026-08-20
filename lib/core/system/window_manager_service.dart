import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../tools/tool_descriptor.dart';

class WindowManagerService {
  WindowManagerService._() {
    _listenForWindowChanges();
  }

  static final WindowManagerService instance = WindowManagerService._();

  /// 跨窗口 invokeMethod 的统一超时。
  ///
  /// desktop_multi_window 的 native 实现中，目标引擎销毁中时
  /// method result 不会被回复（悬挂），Dart 侧 future 永不完成；
  /// 必须靠超时判定窗口已失效，否则调用方永久卡死。
  static const Duration _invokeTimeout = Duration(seconds: 3);

  final Map<String, List<String>> _openWindowIds = {};

  /// 正在创建窗口的工具集合，防止双击/热键连点时并发创建多个窗口。
  final Set<String> _creatingTools = {};

  bool isToolWindowOpen(String toolId) {
    final ids = _openWindowIds[toolId];
    return ids != null && ids.isNotEmpty;
  }

  /// 带超时的跨窗口方法调用，超时抛 [TimeoutException]。
  Future<T?> _safeInvoke<T>(
    WindowController controller,
    String method, [
    dynamic arguments,
  ]) {
    return controller.invokeMethod<T>(method, arguments).timeout(
          _invokeTimeout,
          onTimeout: () => throw TimeoutException(
            'invoke "$method" on window ${controller.windowId} timed out',
          ),
        );
  }

  /// 用 native 的权威窗口列表（MultiWindowManager::windows_）校验缓存，
  /// 移除已销毁窗口的 id。
  ///
  /// onWindowsChanged 是 fire-and-forget 推送，可能丢失或迟到；
  /// 只依赖它清理缓存会让 openToolWindow 反复撞上死窗口 id。
  Future<void> _pruneDeadWindowIds() async {
    if (_openWindowIds.isEmpty) {
      return;
    }
    try {
      final windows = await WindowController.getAll().timeout(_invokeTimeout);
      final activeIds = windows.map((w) => w.windowId).toSet();
      _openWindowIds
        ..updateAll((_, ids) => ids.where(activeIds.contains).toList())
        ..removeWhere((_, ids) => ids.isEmpty);
    } catch (e) {
      // 查询失败时保留缓存，由后续 show/invoke 的超时兜底。
      debugPrint('[WindowManager] Prune dead window ids failed: $e');
    }
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
    // 先清掉缓存里已销毁的窗口 id，避免对死窗口 show/invoke。
    await _pruneDeadWindowIds();

    final ids = _openWindowIds[tool.id];
    if (ids != null && ids.isNotEmpty) {
      final windowId = ids.first;
      try {
        final controller = WindowController.fromWindowId(windowId);
        // show 对已销毁句柄会静默返回成功，play_reveal 才是真正的
        // 存活探针：引擎死了会抛 CHANNEL_UNREGISTERED 或超时。
        await controller.show().timeout(_invokeTimeout);
        await _safeInvoke<void>(controller, 'play_reveal');
        await _disposeOtherHiddenWindows(exceptToolId: tool.id);
        return;
      } catch (e) {
        // show 失败（窗口已销毁）或 play_reveal 超时/异常（引擎半死）：
        // 清掉脏缓存，降级为重新创建窗口。
        debugPrint(
          '[WindowManager] Reopen ${tool.id} window $windowId failed: $e, '
          'falling back to create',
        );
        _openWindowIds.remove(tool.id);
      }
    }

    // 窗口创建是异步的：创建完成前再触发会重复开窗，这里直接忽略并发请求。
    if (!_creatingTools.add(tool.id)) {
      return;
    }

    try {
      final controller = await WindowController.create(
        WindowConfiguration(arguments: tool.id),
      );

      _openWindowIds[tool.id] = [controller.windowId];
      debugPrint(
        '[WindowManager] Opened window for ${tool.id}: ${controller.windowId}',
      );
      await _disposeOtherHiddenWindows(exceptToolId: tool.id);
    } catch (e) {
      debugPrint('[WindowManager] Create window for ${tool.id} failed: $e');
      _openWindowIds.remove(tool.id);
    } finally {
      _creatingTools.remove(tool.id);
    }
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
          // 超时说明目标引擎销毁中/已死，按失效处理清理缓存。
          await _safeInvoke<void>(controller, 'dispose_if_hidden');
        } catch (e) {
          debugPrint(
            '[WindowManager] dispose_if_hidden $windowId failed: $e',
          );
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
