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
    trayManager.addListener(this);
    windowManager.addListener(this);

    await windowManager.setPreventClose(true);
    await _setupLaunchAtStartup();
    await _setupTray();
  }

  Future<void> _setupLaunchAtStartup() async {
    launchAtStartup.setup(
      appName: 'Windows 工具集',
      appPath: Platform.resolvedExecutable,
    );
    _launchAtStartupEnabled = await launchAtStartup.isEnabled();
  }

  Future<void> _setupTray() async {
    final iconPath = [
      Directory.current.path,
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    ].join(Platform.pathSeparator);

    if (await File(iconPath).exists()) {
      await trayManager.setIcon(iconPath);
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
