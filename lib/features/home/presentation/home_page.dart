import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/animations/animation_builders.dart';
import '../../../core/design_tokens/index.dart';
import '../../../core/system/window_manager_service.dart';
import '../../../core/tools/tool_descriptor.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../../../features/settings/presentation/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.tools;
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: 'Windows 工具集',
        subtitle: '选择下方工具开始使用',
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => _openSettings(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.settings,
                  size: 18,
                  color: shad.colorScheme.foreground,
                ),
                const SizedBox(width: Spacing.sm),
                const Text('设置'),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.lg,
                  Spacing.lg,
                  Spacing.md,
                ),
                child: PageSectionHeader(
                  title: '常用工具',
                  subtitle: '统一的工具卡片语言，让首页看起来更像一个成熟的桌面工作台。',
                  icon: Icons.dashboard_customize_outlined,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    0,
                    Spacing.lg,
                    Spacing.lg,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: Spacing.lg,
                    crossAxisSpacing: Spacing.lg,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (_, i) => StaggeredAnimationBuilder(
                    index: i,
                    child: _ToolCard(
                      tool: tools[i],
                      onTap: () => WindowManagerService.instance.openToolWindow(
                        tools[i],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      PageTransitionBuilder.buildPageTransition<void>(
        context: context,
        builder: (_) => const SettingsPage(),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final ToolDescriptor tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return InteractiveSurfaceCard(
      onTap: onTap,
      expand: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            ),
            child: Icon(
              tool.icon,
              size: 28,
              color: shad.colorScheme.secondaryForeground,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            tool.title,
            style: Typography.label.copyWith(
              color: shad.colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            tool.description,
            style: Typography.labelSmall.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
