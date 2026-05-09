import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/system/window_manager_service.dart';
import '../../../core/tools/tool_descriptor.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../features/settings/data/theme_service.dart';
import '../../../features/settings/domain/app_theme_style.dart';
import '../../../features/settings/presentation/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.tools;
    final shad = ShadTheme.of(context);
    final style = ThemeService.instance.currentStyle.value;

    return Scaffold(
      backgroundColor: style == AppThemeStyle.modern
          ? const Color(0xFFF0F4FF)
          : shad.colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: shad.colorScheme.background,
            border: Border(
              bottom: BorderSide(color: shad.colorScheme.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Windows 工具集',
                style: shad.textTheme.h4,
              ),
              const Spacer(),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => _openSettings(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.settings,
                      size: 16,
                      color: shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: 6),
                    const Text('设置'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: tools.length,
            itemBuilder: (_, i) => _ToolCard(
              tool: tools[i],
              onTap: () => WindowManagerService.instance.openToolWindow(tools[i]),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final ToolDescriptor tool;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final style = ThemeService.instance.currentStyle.value;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? shad.colorScheme.accent : shad.colorScheme.card,
            border: Border.all(
              color: _hovered ? shad.colorScheme.ring : shad.colorScheme.border,
            ),
            borderRadius: BorderRadius.circular(
              style == AppThemeStyle.luxury ? 16 : 12,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: shad.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(
                    style == AppThemeStyle.luxury ? 12 : 10,
                  ),
                ),
                child: Icon(
                  widget.tool.icon,
                  size: 22,
                  color: shad.colorScheme.secondaryForeground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.tool.title,
                style: shad.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.tool.description,
                style: shad.textTheme.muted.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
