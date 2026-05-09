import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import 'autostart_settings_page.dart';
import 'backup_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<_SettingsMenuItem> _menuItems = [
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

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '设置',
        subtitle: '管理应用配置和偏好',
        showBack: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _menuItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return _SettingsMenuCard(
            item: item,
            onTap: () => _navigateToSubPage(context, item),
          );
        },
      ),
    );
  }

  void _navigateToSubPage(BuildContext context, _SettingsMenuItem item) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => item.pageBuilder(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
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

class _SettingsMenuCard extends StatefulWidget {
  const _SettingsMenuCard({
    required this.item,
    required this.onTap,
  });

  final _SettingsMenuItem item;
  final VoidCallback onTap;

  @override
  State<_SettingsMenuCard> createState() => _SettingsMenuCardState();
}

class _SettingsMenuCardState extends State<_SettingsMenuCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? shad.colorScheme.accent : shad.colorScheme.card,
            border: Border.all(
              color: _hovered ? shad.colorScheme.ring : shad.colorScheme.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: shad.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.item.icon,
                  size: 18,
                  color: shad.colorScheme.secondaryForeground,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: shad.textTheme.large.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.description,
                      style: shad.textTheme.muted,
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
        ),
      ),
    );
  }
}