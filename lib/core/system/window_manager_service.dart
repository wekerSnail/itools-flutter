import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../tools/tool_descriptor.dart';
import 'app_runtime.dart';

class WindowManagerService {
  WindowManagerService._() {
    // 子窗口进程禁止订阅 onWindowsChanged：不可取消的监听会让
    // 隐藏后的子引擎无法回收（见 main.dart 对子窗口的约束）。
    if (!AppRuntime.isChildWindow) {
      _listenForWindowChanges();
    }
  }

  static final WindowManagerService instance = WindowManagerService._();

  /// 跨窗口 invokeMethod 的统一超时。
  ///
  /// desktop_multi_window 的 native 实现中，目标引擎销毁中时
  /// method result 不会被回复（悬挂），Dart 侧 future 永不完成；
  /// 必须靠超时判定窗口已失效，否则调用方永久卡死。
  static const Duration _invokeTimeout = Duration(seconds: 3);

  final Map<String, List<String>> _openWindowIds = {};

  /// windowId → 同工具内的实例序号（1 起），用于窗口标题区分多开实例。
  final Map<String, int> _instanceByWindowId = {};

  /// 关闭即销毁的临时窗口 id（子窗口「新窗口」开的实例）。
  final Set<String> _destroyOnCloseWindowIds = {};

  /// 同工具已占用（含创建中）的实例序号。窗口销毁后释放；
  /// 隐藏期间保留（隐藏窗口 3 分钟内会被自动销毁回收），
  /// 因此实例号不会累计增长，也无需跨引擎的隐藏通知。
  final Map<String, Set<int>> _usedInstancesByTool = {};

  /// 正在创建窗口的工具集合，防止双击/热键连点时并发创建多个窗口。
  final Set<String> _creatingTools = {};

  StreamSubscription<void>? _windowsChangedSub;

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
    return controller
        .invokeMethod<T>(method, arguments)
        .timeout(
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
        ..updateAll((toolId, ids) {
          for (final id in ids.where((id) => !activeIds.contains(id))) {
            _forgetWindow(toolId, id);
          }
          return ids.where(activeIds.contains).toList();
        })
        ..removeWhere((_, ids) => ids.isEmpty);
    } catch (e) {
      // 查询失败时保留缓存，由后续 show/invoke 的超时兜底。
      debugPrint('[WindowManager] Prune dead window ids failed: $e');
    }
  }

  /// 同工具多开窗口的实例序号：取当前仍占用的最大值 + 1。
  /// 销毁即释放，全部关掉后再开从 1 起，不会累计历史水位。
  int _allocateInstanceNumber(String toolId) {
    final used = _usedInstancesByTool.putIfAbsent(toolId, () => <int>{});
    var maxInstance = 0;
    for (final n in used) {
      if (n > maxInstance) {
        maxInstance = n;
      }
    }
    final next = maxInstance + 1;
    used.add(next);
    return next;
  }

  void _releaseInstanceNumber(String toolId, int instance) {
    final used = _usedInstancesByTool[toolId];
    if (used == null) {
      return;
    }
    used.remove(instance);
    if (used.isEmpty) {
      _usedInstancesByTool.remove(toolId);
    }
  }

  /// 释放某窗口的实例簿记（临时窗口标记 + 实例号）。
  /// 供各销毁/失效路径统一调用；`_openWindowIds` 的清理由
  /// 调用方按各自语义处理（部分路径在遍历中不可变更 map 结构）。
  void _forgetWindow(String toolId, String windowId) {
    _destroyOnCloseWindowIds.remove(windowId);
    final instance = _instanceByWindowId.remove(windowId);
    if (instance != null) {
      _releaseInstanceNumber(toolId, instance);
    }
  }

  void _trackWindow(
    String toolId,
    String windowId,
    int instance, {
    bool destroyOnClose = false,
  }) {
    _openWindowIds.putIfAbsent(toolId, () => <String>[]).add(windowId);
    _instanceByWindowId[windowId] = instance;
    if (destroyOnClose) {
      _destroyOnCloseWindowIds.add(windowId);
    } else {
      _destroyOnCloseWindowIds.remove(windowId);
    }
  }

  /// 隐藏窗口重新展示时沿用原实例号（隐藏期间未释放），标题无需变更。
  void _listenForWindowChanges() {
    _windowsChangedSub = onWindowsChanged.listen((_) async {
      try {
        final windows = await WindowController.getAll();
        final activeIds = windows.map((w) => w.windowId).toSet();
        final toRemove = <String>[];
        for (final entry in _openWindowIds.entries) {
          for (final id in entry.value.where((id) => !activeIds.contains(id))) {
            _forgetWindow(entry.key, id);
          }
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
      // 优先唤起主页打开的常驻窗口；仅剩临时实例（新窗口）时也回退
      // 展示它，避免为主页入口重复开一个同工具窗口。
      final windowId =
          ids
              .where((id) => !_destroyOnCloseWindowIds.contains(id))
              .firstOrNull ??
          ids.first;
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
        // 只移除失败的 windowId，避免误清同工具其他仍存活的窗口。
        _removeWindowId(tool.id, windowId);
      }
    }

    // 窗口创建是异步的：创建完成前再触发会重复开窗，这里直接忽略并发请求。
    if (!_creatingTools.add(tool.id)) {
      return;
    }

    try {
      final instance = _allocateInstanceNumber(tool.id);
      try {
        final controller = await WindowController.create(
          WindowConfiguration(arguments: encodeWindowArgs(tool.id, instance)),
        );
        _trackWindow(tool.id, controller.windowId, instance);
        debugPrint(
          '[WindowManager] Opened window for ${tool.id}: '
          '${controller.windowId} (#$instance)',
        );
      } catch (e) {
        _releaseInstanceNumber(tool.id, instance);
        rethrow;
      }
      await _disposeOtherHiddenWindows(exceptToolId: tool.id);
    } catch (e) {
      // create 失败时尚未写入新 id，保留该工具已有窗口缓存。
      debugPrint('[WindowManager] Create window for ${tool.id} failed: $e');
    } finally {
      _creatingTools.remove(tool.id);
    }
  }

  void _removeWindowId(String toolId, String windowId) {
    _forgetWindow(toolId, windowId);
    final ids = _openWindowIds[toolId];
    if (ids == null) return;
    ids.remove(windowId);
    if (ids.isEmpty) {
      _openWindowIds.remove(toolId);
    }
  }

  Future<void> openNewToolWindow(ToolDescriptor tool) async {
    if (AppRuntime.isChildWindow) {
      // 子窗口不直接簿记窗口（避免残留订阅/孤儿窗口）；转发主引擎创建，
      // 保证 closeAll 退出清理能覆盖到这些实例。
      final ok = await _forwardToMainEngine('open_new_tool_window', tool.id);
      if (!ok) {
        throw StateError('open_new_tool_window failed in child window');
      }
      return;
    }
    final instance = _allocateInstanceNumber(tool.id);
    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          arguments: encodeWindowArgs(tool.id, instance, destroyOnClose: true),
        ),
      );
      _trackWindow(
        tool.id,
        controller.windowId,
        instance,
        destroyOnClose: true,
      );
      debugPrint(
        '[WindowManager] Opened new window for ${tool.id}: '
        '${controller.windowId} (#$instance)',
      );
    } catch (e) {
      _releaseInstanceNumber(tool.id, instance);
      rethrow;
    }
  }

  /// 子窗口 → 主引擎方法转发。主窗口无启动参数（windowArgument 为空）。
  Future<bool> _forwardToMainEngine(String method, Object? arguments) async {
    try {
      final windows = await WindowController.getAll().timeout(_invokeTimeout);
      final mainWindow = windows.where((w) => w.arguments.isEmpty).firstOrNull;
      if (mainWindow == null) {
        debugPrint('[WindowManager] Main window not found for $method');
        return false;
      }
      await _safeInvoke<void>(
        WindowController.fromWindowId(mainWindow.windowId),
        method,
        arguments,
      );
      return true;
    } catch (e) {
      debugPrint('[WindowManager] Forward $method failed: $e');
      return false;
    }
  }

  /// 主窗口退出前销毁全部工具子窗口，并取消事件订阅。
  Future<void> closeAll() async {
    final entries = List<MapEntry<String, List<String>>>.from(
      _openWindowIds.entries,
    );
    for (final entry in entries) {
      for (final windowId in List<String>.from(entry.value)) {
        try {
          final controller = WindowController.fromWindowId(windowId);
          await _safeInvoke<void>(controller, 'force_close');
        } catch (e) {
          debugPrint('[WindowManager] closeAll $windowId failed: $e');
        }
        _forgetWindow(entry.key, windowId);
      }
      _openWindowIds.remove(entry.key);
    }
    await dispose();
  }

  /// 取消 onWindowsChanged 订阅。可重复调用。
  Future<void> dispose() async {
    await _windowsChangedSub?.cancel();
    _windowsChangedSub = null;
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
          debugPrint('[WindowManager] dispose_if_hidden $windowId failed: $e');
          _forgetWindow(entry.key, windowId);
          entry.value.remove(windowId);
        }
      }

      if (entry.value.isEmpty) {
        _openWindowIds.remove(entry.key);
      }
    }
  }

  /// 窗口启动参数：`toolId|instance|hide|close`
  /// - `hide`：主页打开的常驻窗口，关闭即隐藏（可快速重开）
  /// - `close`：子窗口「新窗口」开的临时实例，关闭即销毁
  static String encodeWindowArgs(
    String toolId,
    int instance, {
    bool destroyOnClose = false,
  }) => '$toolId|$instance|${destroyOnClose ? 'close' : 'hide'}';

  static String? decodeToolId(String? args) {
    if (args == null || args.isEmpty) return null;
    return args.split('|').first;
  }

  /// 窗口实例序号（1 起）；旧格式参数无后缀时视为 1。
  static int decodeInstanceNumber(String? args) {
    if (args == null || args.isEmpty) return 1;
    final parts = args.split('|');
    if (parts.length < 2) return 1;
    return int.tryParse(parts[1]) ?? 1;
  }

  /// 是否为「关闭即销毁」的临时窗口（子窗口新实例）。
  static bool decodeDestroyOnClose(String? args) {
    if (args == null || args.isEmpty) return false;
    final parts = args.split('|');
    return parts.length >= 3 && parts[2] == 'close';
  }

  /// 标题后缀：统一追加实例序号（JSON 格式化 1 / 2 / 3），便于多窗口区分。
  static String formatInstanceTitle(String baseTitle, int instance) =>
      '$baseTitle $instance';
}
