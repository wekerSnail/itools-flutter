import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener, WindowListener {
  AppTrayService._();

  static final AppTrayService instance = AppTrayService._();

  bool _initialized = false;
  bool _quitting = false;
  bool _launchAtStartupEnabled = false;
  Timer? _trayRecoveryTimer;

  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) {
      debugPrint('[Tray] Skipping initialization: _initialized=$_initialized, isWindows=${Platform.isWindows}');
      return;
    }

    _initialized = true;
    debugPrint('[Tray] Starting initialization...');
    try {
      // 必须先添加监听器
      debugPrint('[Tray] Adding listeners...');
      trayManager.addListener(this);
      windowManager.addListener(this);

      // 设置窗口不能被关闭（最小化到托盘）
      debugPrint('[Tray] Setting window prevent close...');
      await windowManager.setPreventClose(true);
      
      await _setupLaunchAtStartup();
      
      // 延迟一下确保平台完全准备好
      debugPrint('[Tray] Waiting for platform to be ready...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('[Tray] Setting up tray...');
      await _setupTray();

      // 启动托盘恢复检查（每30秒检查一次）
      debugPrint('[Tray] Starting recovery check timer...');
      _startTrayRecoveryCheck();
      
      debugPrint('[Tray] ✓ Initialization complete!');
    } catch (e) {
      debugPrint('[Tray] ✗ Initialize failed: $e');
      stderr.writeln('[Tray] Initialize failed: $e');
      _initialized = false;
    }
  }

  /// 启动定期的托盘恢复检查
  void _startTrayRecoveryCheck() {
    _trayRecoveryTimer?.cancel();
    _trayRecoveryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          if (!_quitting && _initialized) {
            await _ensureTrayExists();
          }
        } catch (e) {
          stderr.writeln('[Tray] recovery check failed: $e');
        }
      },
    );
  }

  /// 确保托盘存在，如果丢失则重建
  Future<void> _ensureTrayExists() async {
    try {
      // 尝试获取托盘状态，如果失败则重建
      await _setupTray();
    } catch (e) {
      stderr.writeln('[Tray] ensure tray exists failed: $e');
    }
  }

  Future<void> _setupLaunchAtStartup() async {
    try {
      launchAtStartup.setup(
        appName: 'Windows 工具集',
        appPath: Platform.resolvedExecutable,
      );
      _launchAtStartupEnabled = await launchAtStartup.isEnabled();
    } catch (e) {
      stderr.writeln('[Tray] setup launch at startup failed: $e');
    }
  }

  Future<void> _setupTray() async {
    try {
      debugPrint('[Tray._setupTray] Starting...');
      
      // 优先按可执行文件目录定位，兼容直接双击 Release\itools.exe 运行
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final currentDir = Directory.current.path;

      final candidatePaths = <String>[
        [
          executableDir,
          'data',
          'flutter_assets',
          'assets',
          'tray_icon.ico',
        ].join(Platform.pathSeparator),
        [
          executableDir,
          'data',
          'flutter_assets',
          'tray_icon.ico',
        ].join(Platform.pathSeparator),
        [
          executableDir,
          'app_icon.ico',
        ].join(Platform.pathSeparator),
        [
          currentDir,
          'windows',
          'runner',
          'resources',
          'app_icon.ico',
        ].join(Platform.pathSeparator),
        [
          currentDir,
          'assets',
          'tray_icon.ico',
        ].join(Platform.pathSeparator),
        [
          currentDir,
          'build',
          'windows',
          'x64',
          'runner',
          'Release',
          'data',
          'flutter_assets',
          'assets',
          'tray_icon.ico',
        ].join(Platform.pathSeparator),
      ];

      String? iconPathToUse;
      for (final path in candidatePaths) {
        debugPrint('[Tray._setupTray] Checking path: $path');
        if (await File(path).exists()) {
          iconPathToUse = path;
          debugPrint('[Tray._setupTray] ✓ Found icon: $iconPathToUse');
          break;
        }
      }

      if (iconPathToUse != null && iconPathToUse.isNotEmpty) {
        debugPrint('[Tray._setupTray] Setting tooltip...');
        await trayManager.setToolTip('Windows 工具集 - 点击打开主界面');
        
        debugPrint('[Tray._setupTray] Setting context menu first...');
        await _refreshContextMenu();
        
        debugPrint('[Tray._setupTray] Now setting icon: $iconPathToUse');
        // 转换为绝对路径（使用正斜杠）
        final absolutePath = File(iconPathToUse).absolute.path;
        final normalizedPath = absolutePath.replaceAll('\\', '/');
        debugPrint('[Tray._setupTray] Normalized path: $normalizedPath');
        
        await trayManager.setIcon(normalizedPath, isTemplate: false);
        debugPrint('[Tray._setupTray] ✓ Icon set successfully');
        
        debugPrint('[Tray._setupTray] ✓ Setup complete!');
      } else {
        debugPrint('[Tray._setupTray] ✗ Icon not found!');
        debugPrint('[Tray._setupTray] Searched candidate paths:');
        for (var i = 0; i < candidatePaths.length; i++) {
          debugPrint('[Tray._setupTray]   ${i + 1}. ${candidatePaths[i]}');
        }
      }
    } catch (e, st) {
      debugPrint('[Tray._setupTray] ✗ Failed: $e');
      debugPrint('[Tray._setupTray] Stacktrace: $st');
      stderr.writeln('[Tray] setup tray failed: $e');
    }
  }

  Future<void> _refreshContextMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '打开主界面'),
          MenuItem.separator(),
          MenuItem(
            key: 'startup',
            label: _launchAtStartupEnabled ? '取消开机自启' : '开机自启',
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _toggleStartup() async {
    if (_launchAtStartupEnabled) {
      await launchAtStartup.disable();
      _launchAtStartupEnabled = false;
    } else {
      await launchAtStartup.enable();
      _launchAtStartupEnabled = true;
    }
    await _refreshContextMenu();
  }

  Future<void> _exitApp() async {
    _quitting = true;
    _trayRecoveryTimer?.cancel();
    try {
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (e) {
      stderr.writeln('[Tray] exit app failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    if (_quitting) {
      return;
    }
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() async {
    try {
      await _showMainWindow();
    } catch (e) {
      stderr.writeln('[Tray] tray mouse down failed: $e');
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    try {
      await trayManager.popUpContextMenu();
    } catch (e) {
      stderr.writeln('[Tray] tray right mouse down failed: $e');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    try {
      switch (menuItem.key) {
        case 'show':
          await _showMainWindow();
          break;
        case 'startup':
          await _toggleStartup();
          break;
        case 'exit':
          await _exitApp();
          break;
        default:
          stderr.writeln('[Tray] unknown menu item: ${menuItem.key}');
      }
    } catch (e) {
      stderr.writeln('[Tray] menu item click failed: $e');
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    _trayRecoveryTimer?.cancel();
    _trayRecoveryTimer = null;
  }
}
