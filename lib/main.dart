import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/system/app_tray_service.dart';
import 'core/system/single_instance_manager.dart';
import 'core/system/window_manager_service.dart';
import 'core/system/window_reveal_controller.dart';
import 'core/tools/tool_registry.dart';
import 'features/hotkey_settings/data/hotkey_action_registry.dart';
import 'features/hotkey_settings/domain/hotkey_action_descriptor.dart';

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

  final singleInstance = SingleInstanceManager.instance;
  if (!singleInstance.tryAcquire()) {
    debugPrint('[Main] Another instance is already running, exiting');
    return;
  }

  debugPrint('[Main] Single instance acquired, continuing startup');

  await windowManager.ensureInitialized();
  debugPrint('[Main] Window manager initialized');

  const windowOptions = WindowOptions(
    size: Size(680, 520),
    minimumSize: Size(580, 450),
    center: true,
    title: '工具集',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    debugPrint('[Main] Window ready to show');
    await windowManager.show();
    await windowManager.focus();

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
  runApp(const ProviderScope(child: ToolboxApp()));
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
