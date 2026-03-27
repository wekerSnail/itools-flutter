import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener, WindowListener {
  AppTrayService._();

  static final AppTrayService instance = AppTrayService._();

  bool _initialized = false;
  bool _quitting = false;
  bool _launchAtStartupEnabled = false;

  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) {
      return;
    }

    _initialized = true;
    try {
      trayManager.addListener(this);
      windowManager.addListener(this);

      await windowManager.setPreventClose(true);
      await _setupLaunchAtStartup();
      await _setupTray();
    } catch (e) {
      stderr.writeln('[Tray] initialize failed: $e');
    }
  }

  Future<void> _setupLaunchAtStartup() async {
    launchAtStartup.setup(
      appName: 'Windows 工具集',
      appPath: Platform.resolvedExecutable,
    );
    _launchAtStartupEnabled = await launchAtStartup.isEnabled();
  }

  Future<void> _setupTray() async {
    final projectIconPath = [
      Directory.current.path,
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    ].join(Platform.pathSeparator);

    final assetIconPath = [
      Directory.current.path,
      'assets',
      'tray_icon.ico',
    ].join(Platform.pathSeparator);

    var iconPathToUse = '';
    if (await File(projectIconPath).exists()) {
      iconPathToUse = projectIconPath;
    } else if (await File(assetIconPath).exists()) {
      iconPathToUse = assetIconPath;
    }

    if (iconPathToUse.isNotEmpty) {
      await trayManager.setIcon(iconPathToUse);
    } else {
      stderr.writeln('[Tray] icon file not found, tray icon may not show.');
    }

    await trayManager.setToolTip('Windows 工具集');
    await _refreshContextMenu();
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
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
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
    await _showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
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
    }
  }
}
