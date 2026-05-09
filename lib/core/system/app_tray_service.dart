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
  bool _trayIconConfigured = false;
  Timer? _trayRecoveryTimer;

  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) {
      debugPrint(
        '[Tray] Skipping initialization: _initialized=$_initialized, isWindows=${Platform.isWindows}',
      );
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
      await Future<void>.delayed(const Duration(milliseconds: 500));

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
    _trayRecoveryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        if (!_quitting && _initialized) {
          await _ensureTrayExists();
        }
      } catch (e) {
        stderr.writeln('[Tray] recovery check failed: $e');
      }
    });
  }

  /// 确保托盘存在，如果丢失则重建
  Future<void> _ensureTrayExists() async {
    try {
      if (!_trayIconConfigured) {
        await _setupTray();
      }

      await _refreshContextMenu();
    } catch (e) {
      stderr.writeln('[Tray] ensure tray exists failed: $e');
    }
  }

  Future<void> _setupLaunchAtStartup() async {
    try {
      final executablePath = Platform.resolvedExecutable;
      final absolutePath = File(executablePath).absolute.path;

      debugPrint('[Tray] Setup launch at startup:');
      debugPrint('[Tray]   - App name: Windows 工具集');
      debugPrint('[Tray]   - Executable path: $executablePath');
      debugPrint('[Tray]   - Absolute path: $absolutePath');

      launchAtStartup.setup(appName: 'Windows 工具集', appPath: absolutePath);

      _launchAtStartupEnabled = await launchAtStartup.isEnabled();
      debugPrint('[Tray] Launch at startup enabled: $_launchAtStartupEnabled');

      if (!_launchAtStartupEnabled) {
        debugPrint('[Tray] Attempting to enable launch at startup...');
        await launchAtStartup.enable();
        _launchAtStartupEnabled = await launchAtStartup.isEnabled();
        debugPrint('[Tray] Launch at startup enabled after attempt: $_launchAtStartupEnabled');
      }

      if (Platform.isWindows) {
        await _verifyRegistry();
      }
    } catch (e) {
      stderr.writeln('[Tray] setup launch at startup failed: $e');
      debugPrint('[Tray] ✗ Launch at startup setup failed: $e');
    }
  }

  Future<void> _verifyRegistry() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" | Select-Object -Property "*工具集*"',
      ]);

      if (result.stdout.toString().trim().isNotEmpty) {
        debugPrint('[Tray] Registry verification: ${result.stdout}');
      } else {
        debugPrint('[Tray] Warning: Registry entry not found, attempting manual setup...');
        await _manualSetRegistry();
      }
    } catch (e) {
      debugPrint('[Tray] Failed to verify registry: $e');
    }
  }

  Future<void> _manualSetRegistry() async {
    try {
      final executablePath = Platform.resolvedExecutable;
      final absolutePath = File(executablePath).absolute.path;
      final appDir = File(absolutePath).parent.path;
      final vbsPath = '$appDir\\launch-elevated.vbs';

      debugPrint('[Tray] Creating VBS script: $vbsPath');

      final vbsContent = 'Set objShell = CreateObject("Shell.Application")\n'
          'objShell.ShellExecute "$absolutePath", "", "$appDir", "runas", 1\n';

      await File(vbsPath).writeAsString(vbsContent);
      debugPrint('[Tray] VBS script created successfully');

      final regCommand =
          'Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" '
          '-Name "Windows 工具集" -Value "wscript.exe \\"$vbsPath\\"" -Force';

      final result = await Process.run('powershell', ['-Command', regCommand]);

      if (result.exitCode == 0) {
        debugPrint('[Tray] ✓ Registry updated successfully via VBS script');
        _launchAtStartupEnabled = true;
      } else {
        debugPrint('[Tray] ✗ Failed to update registry: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('[Tray] ✗ Manual registry setup failed: $e');
    }
  }

  Future<bool> checkLaunchAtStartupStatus() async {
    try {
      final isEnabled = await launchAtStartup.isEnabled();
      debugPrint('[Tray] Launch at startup status: $isEnabled');

      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-Command',
          'Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" | Select-Object -Property "*工具集*"',
        ]);

        final registryValue = result.stdout.toString().trim();
        debugPrint('[Tray] Registry check: $registryValue');

        if (registryValue.isEmpty) {
          debugPrint('[Tray] Registry entry missing, launch at startup may not work');
          return false;
        }
      }

      return isEnabled;
    } catch (e) {
      debugPrint('[Tray] Failed to check launch at startup status: $e');
      return false;
    }
  }

  Future<bool> fixLaunchAtStartup() async {
    try {
      debugPrint('[Tray] Fixing launch at startup...');

      await launchAtStartup.disable();
      await _setupLaunchAtStartup();

      final isEnabled = await checkLaunchAtStartupStatus();
      debugPrint('[Tray] Launch at startup fix result: $isEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('[Tray] Failed to fix launch at startup: $e');
      return false;
    }
  }

  Future<void> disableLaunchAtStartup() async {
    try {
      debugPrint('[Tray] Disabling launch at startup...');
      await launchAtStartup.disable();
      _launchAtStartupEnabled = false;
      await _refreshContextMenu();
      debugPrint('[Tray] Launch at startup disabled');
    } catch (e) {
      debugPrint('[Tray] Failed to disable launch at startup: $e');
      rethrow;
    }
  }

  Future<void> _setupTray() async {
    try {
      debugPrint('[Tray._setupTray] Starting...');

      if (_trayIconConfigured) {
        debugPrint('[Tray._setupTray] Tray icon already configured, skipping');
        return;
      }

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
        [executableDir, 'app_icon.ico'].join(Platform.pathSeparator),
        [
          currentDir,
          'windows',
          'runner',
          'resources',
          'app_icon.ico',
        ].join(Platform.pathSeparator),
        [currentDir, 'assets', 'tray_icon.ico'].join(Platform.pathSeparator),
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

        await trayManager.setIcon(normalizedPath);
        _trayIconConfigured = true;
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

      if (Platform.isWindows) {
        await _verifyRegistry();
      }
    }
    await _refreshContextMenu();
  }

  Future<void> _exitApp() async {
    _quitting = true;
    _trayRecoveryTimer?.cancel();
    try {
      _trayIconConfigured = false;
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
