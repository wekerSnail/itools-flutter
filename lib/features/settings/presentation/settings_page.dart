import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../../hotkey_settings/presentation/hotkey_settings_page.dart';
import 'autostart_settings_page.dart';
import 'backup_settings_page.dart';
import 'theme_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<_SettingsMenuItem> _menuItems = [
    _SettingsMenuItem(
      icon: LucideIcons.sunMoon,
      title: '主题设置',
      description: '选择亮色、暗色或跟随系统主题',
      pageBuilder: () => const ThemeSettingsPage(),
    ),
    _SettingsMenuItem(
      icon: LucideIcons.keyboard,
      title: '热键设置',
      description: '配置全局快捷键，快速触发常用操作',
      pageBuilder: () => const HotkeySettingsPage(),
    ),
    _SettingsMenuItem(
      icon: LucideIcons.database,
      title: '备份还原',
      description: '导出当前数据或导入历史备份',
      pageBuilder: () => const BackupSettingsPage(),
    ),
    _SettingsMenuItem(
      icon: LucideIcons.power,
      title: '开机自启',
      description: '设置开机时自动启动应用',
      pageBuilder: () => const AutostartSettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '设置',
        subtitle: '管理应用配置和偏好',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const PageSectionHeader(
            title: '偏好入口',
            subtitle: '把常用配置集中在一个地方，入口表达更统一、层级也更清楚。',
            icon: LucideIcons.slidersHorizontal,
          ),
          const SizedBox(height: Spacing.md),
          ..._menuItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _menuItems.length - 1 ? 0 : Spacing.md,
              ),
              child: _SettingsMenuCard(
                item: item,
                onTap: () => _navigateToSubPage(context, item),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _navigateToSubPage(BuildContext context, _SettingsMenuItem item) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            item.pageBuilder(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
}

class _SettingsMenuItem {
  final IconData icon;
  final String title;
  final String description;
  final Widget Function() pageBuilder;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.pageBuilder,
  });
}

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({required this.item, required this.onTap});

  final _SettingsMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return InteractiveSurfaceCard(
      onTap: onTap,
      expand: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: shad.colorScheme.secondaryForeground,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  item.description,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: shad.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}
