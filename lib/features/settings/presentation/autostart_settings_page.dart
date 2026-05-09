import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/system/app_tray_service.dart';
import '../../../core/widgets/page_header.dart';

class AutostartSettingsPage extends StatefulWidget {
  const AutostartSettingsPage({super.key});

  @override
  State<AutostartSettingsPage> createState() => _AutostartSettingsPageState();
}

class _AutostartSettingsPageState extends State<AutostartSettingsPage> {
  bool _isEnabled = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final status = await AppTrayService.instance.checkLaunchAtStartupStatus();
      if (mounted) {
        setState(() {
          _isEnabled = status;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showToast('获取开机自启状态失败：$e');
      }
    }
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<void> _toggleAutostart(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        await AppTrayService.instance.fixLaunchAtStartup();
      } else {
        await AppTrayService.instance.fixLaunchAtStartup();
      }
      
      await _loadStatus();
      
      if (mounted) {
        _showToast(value ? '已开启开机自启' : '已关闭开机自启');
      }
    } catch (e) {
      if (mounted) {
        _showToast('设置开机自启失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '开机自启',
        subtitle: '设置开机时是否自动启动应用',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.power,
                      size: 16,
                      color: shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text('开机自启设置', style: shad.textTheme.large),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '开机时自动启动',
                              style: shad.textTheme.large.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '开启后，Windows 启动时会自动运行此应用',
                              style: shad.textTheme.muted,
                            ),
                          ],
                        ),
                      ),
                      ShadSwitch(
                        value: _isEnabled,
                        onChanged: _busy ? null : _toggleAutostart,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 16,
                      color: shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text('说明', style: shad.textTheme.large),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('• 开机自启功能通过 Windows 注册表实现。'),
                const SizedBox(height: 6),
                const Text('• 开启后，应用会在 Windows 启动时自动运行，并最小化到系统托盘。'),
                const SizedBox(height: 6),
                const Text('• 如果遇到问题，可以尝试关闭后重新开启。'),
                const SizedBox(height: 6),
                const Text('• 某些安全软件可能会阻止开机自启功能，请确保已添加信任。'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.settings,
                      size: 16,
                      color: shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text('故障排除', style: shad.textTheme.large),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('如果开机自启不生效，请尝试以下步骤：'),
                const SizedBox(height: 8),
                const Text('1. 关闭开机自启开关'),
                const SizedBox(height: 4),
                const Text('2. 等待几秒钟'),
                const SizedBox(height: 4),
                const Text('3. 重新开启开机自启开关'),
                const SizedBox(height: 4),
                const Text('4. 重启电脑测试是否生效'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    onPressed: _busy ? null : _fixAutostart,
                    child: const Text('修复开机自启'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fixAutostart() async {
    setState(() => _busy = true);
    try {
      final result = await AppTrayService.instance.fixLaunchAtStartup();
      await _loadStatus();
      
      if (mounted) {
        _showToast(result ? '修复成功' : '修复失败，请手动检查注册表');
      }
    } catch (e) {
      if (mounted) {
        _showToast('修复失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}