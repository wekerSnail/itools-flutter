import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/providers/scheduler_provider.dart';
import 'core/providers/task_runner_provider.dart';
import 'core/system/app_runtime.dart';
import 'core/system/app_tray_service.dart';
import 'core/system/window_manager_service.dart';
import 'core/system/window_reveal_controller.dart';
import 'core/tools/tool_registry.dart';
import 'features/hotkey_settings/data/hotkey_action_registry.dart';
import 'features/hotkey_settings/domain/hotkey_action_descriptor.dart';
import 'features/scheduler/domain/scheduled_task.dart';

void _registerBuiltinHotkeyActions() {
  final registry = HotkeyActionRegistry.instance
    ..register(
      HotkeyActionDescriptor(
        id: 'open_main_window',
        title: '打开主窗口',
        description: '显示/隐藏应用主窗口',
        icon: LucideIcons.appWindow,
        onTrigger: () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );

  for (final tool in ToolRegistry.tools) {
    registry.register(
      HotkeyActionDescriptor(
        id: 'open_${tool.id}',
        title: '打开${tool.title}',
        description: '打开${tool.title}页面',
        icon: tool.icon,
        onTrigger: () {
          WindowManagerService.instance.openToolWindow(tool);
        },
      ),
    );
  }

  debugPrint('[Main] Registered ${registry.actions.length} hotkey actions');
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] Flutter binding initialized');

  if (args.isNotEmpty && args.first == 'multi_window') {
    AppRuntime.isChildWindow = true;
    final toolId = WindowManagerService.decodeToolId(args.elementAtOrNull(2));
    debugPrint('[Main] Child window launched: toolId=$toolId');

    final tool = toolId != null ? ToolRegistry.findById(toolId) : null;
    final windowSize = tool?.windowSize ?? const Size(900, 650);
    final minSize = tool?.minWindowSize ?? const Size(700, 500);
    final title = tool?.title ?? '工具集';

    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: minSize,
      center: true,
      title: title,
    );

    final lifecycleListener = _ChildWindowLifecycleListener();

    // 子窗口采用“关闭即隐藏 + 空闲超时自动销毁”策略：
    // - 关闭后短期内重开更丝滑
    // - 长时间不用会自动释放内存
    await windowManager.setPreventClose(true);
    windowManager.addListener(lifecycleListener);

    final currentWindow = await WindowController.fromCurrentEngine();
    await currentWindow.setWindowMethodHandler((call) async {
      if (call.method == 'dispose_if_hidden') {
        await lifecycleListener.disposeIfHidden();
      } else if (call.method == 'play_reveal') {
        await windowManager.focus();
        WindowRevealController.instance.playReveal();
      }
      return null;
    });

    await windowManager.setAlignment(Alignment.center);
    // 使用回调形式：窗口先隐藏，等 Flutter 渲染完成后再显示，避免黑屏闪烁
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    runApp(ProviderScope(child: ToolboxApp(toolId: toolId)));

    return;
  }

  // 热键动作仅在主窗口进程中注册，避免子窗口进程初始化 WindowManagerService
  // 的流订阅，防止子进程在窗口关闭后仍然存活导致内存泄漏
  _registerBuiltinHotkeyActions();

  // 单实例检测在 native 侧（windows/runner/main.cpp）完成：
  // 第二实例在 wWinMain 就被拦截并激活已有窗口，根本不会执行到这里。
  // 此处不再做 Dart 侧重复检测（历史上它用的 mutex 名与 native 不一致、
  // 按标题查找的窗口标题也不对，属于永远放行的死代码）。

  await windowManager.ensureInitialized();
  debugPrint('[Main] Window manager initialized');

  // 主引擎持有全局 ProviderContainer，供跨窗口调用的处理器读取状态
  final container = ProviderContainer();
  await _registerMainWindowMethodHandler(container);

  const windowOptions = WindowOptions(
    size: Size(680, 520),
    minimumSize: Size(580, 450),
    center: true,
    title: '工具集',
  );

  // 开机自启动（--minimized）时仅托盘驻留，不弹主窗口
  final startMinimized = args.contains('--minimized');
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    debugPrint('[Main] Window ready to show');
    if (!startMinimized) {
      await windowManager.show();
      await windowManager.focus();
    }

    debugPrint('[Main] Window is now visible, initializing tray...');
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await AppTrayService.instance.initialize();
      debugPrint('[Main] Tray service initialized successfully');
    } catch (e, st) {
      debugPrint('[Main] Tray initialization failed: $e');
      debugPrint('[Main] Stack: $st');
    }
  });

  debugPrint('[Main] Running app');
  runApp(UncontrolledProviderScope(
    container: container,
    child: const ToolboxApp(),
  ));
}

/// 注册主窗口的跨窗口方法处理器。
///
/// 子窗口（调度器窗口）的“立即运行”通过 desktop_multi_window
/// 转发到主引擎执行，保证任务执行与日志写入收敛到唯一的调度器。
Future<void> _registerMainWindowMethodHandler(
  ProviderContainer container,
) async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    await controller.setWindowMethodHandler((call) async {
      if (call.method == 'run_task_now') {
        return _runTaskNowInMainEngine(
          container,
          call.arguments?.toString(),
        );
      }
      return null;
    });
  } catch (e) {
    debugPrint('[Main] Register window method handler failed: $e');
  }
}

Future<bool> _runTaskNowInMainEngine(
  ProviderContainer container,
  String? taskId,
) async {
  if (taskId == null) {
    return false;
  }
  final tasks = container.read(schedulerProvider).value ?? <ScheduledTask>[];
  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  if (task == null) {
    debugPrint('[Main] run_task_now: task not found: $taskId');
    return false;
  }
  // 提交即返回：不 await 任务执行，避免长任务把跨窗口调用挂住
  // （子窗口按钮转圈到任务结束，甚至引擎切换期永久悬挂）。
  // 执行状态由子窗口监听 tasks.json / 日志变化自行刷新。
  unawaited(
    container.read(taskRunnerProvider.notifier).runNow(task).catchError((
      Object e,
    ) {
      debugPrint('[Main] run_task_now execute failed: $e');
    }),
  );
  return true;
}

class _ChildWindowLifecycleListener with WindowListener {
  static const Duration _autoDisposeDelay = Duration(minutes: 3);

  Timer? _disposeTimer;
  bool _allowRealClose = false;

  @override
  void onWindowClose() async {
    if (_allowRealClose) {
      return;
    }

    await windowManager.hide();
    _scheduleAutoDispose();
  }

  @override
  void onWindowFocus() {
    _cancelAutoDispose();
  }

  void _scheduleAutoDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = Timer(_autoDisposeDelay, () async {
      await disposeIfHidden();
    });
  }

  void _cancelAutoDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  Future<void> disposeIfHidden() async {
    _cancelAutoDispose();

    final visible = await windowManager.isVisible();
    if (visible) {
      return;
    }

    _allowRealClose = true;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
