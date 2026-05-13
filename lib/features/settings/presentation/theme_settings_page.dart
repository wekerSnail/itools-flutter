import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

IconData _themeStyleIcon(AppThemeStyle style) {
  switch (style) {
    case AppThemeStyle.modern:
      return LucideIcons.palette;
    case AppThemeStyle.luxury:
      return LucideIcons.gem;
  }
}

IconData _themeModeIcon(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return LucideIcons.sun;
    case AppThemeMode.dark:
      return LucideIcons.moon;
    case AppThemeMode.system:
      return LucideIcons.sunMoon;
  }
}

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shad = ShadTheme.of(context);
    final themeState = ref.watch(themeProvider);

    return themeState.when(
      loading: () => Scaffold(
        backgroundColor: shad.colorScheme.background,
        appBar: const PageHeader(
          title: '主题设置',
          subtitle: '选择视觉风格和色调',
          showBack: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: shad.colorScheme.background,
        appBar: const PageHeader(
          title: '主题设置',
          subtitle: '选择视觉风格和色调',
          showBack: true,
        ),
        body: Center(child: Text('加载失败: $error')),
      ),
      data: (state) {
        final notifier = ref.read(themeProvider.notifier);

        return Scaffold(
          backgroundColor: shad.colorScheme.background,
          appBar: const PageHeader(
            title: '主题设置',
            subtitle: '选择视觉风格和色调',
            showBack: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              const PageSectionHeader(
                title: '主题风格库',
                subtitle: '选择最对胃口的工作氛围。',
                icon: LucideIcons.palette,
              ),
              const SizedBox(height: Spacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 960 ? 2 : 1;
                  final totalSpacing = (columns - 1) * Spacing.md;
                  final itemWidth =
                      (constraints.maxWidth - totalSpacing) / columns;

                  return Wrap(
                    spacing: Spacing.md,
                    runSpacing: Spacing.md,
                    children: AppThemeStyle.values
                        .map((style) {
                          return SizedBox(
                            width: itemWidth,
                            child: _ThemeStyleCard(
                              style: style,
                              isSelected: style == state.style,
                              onTap: () => notifier.setStyle(style),
                            ),
                          );
                        })
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: Spacing.xl),
              const PageSectionHeader(
                title: '色调模式',
                subtitle: '亮、暗、跟随系统三种模式。',
                icon: LucideIcons.sunMoon,
              ),
              const SizedBox(height: Spacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 1;
                  final totalSpacing = (columns - 1) * Spacing.md;
                  final itemWidth =
                      (constraints.maxWidth - totalSpacing) / columns;

                  return Wrap(
                    spacing: Spacing.md,
                    runSpacing: Spacing.md,
                    children: AppThemeMode.values
                        .map((mode) {
                          return SizedBox(
                            width: itemWidth,
                            child: _ThemeModeCard(
                              mode: mode,
                              isSelected: mode == state.mode,
                              onTap: () => notifier.setMode(mode),
                            ),
                          );
                        })
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: Spacing.md),
              _ThemeBackupHintCard(),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeStyleCard extends StatelessWidget {
  const _ThemeStyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return InteractiveSurfaceCard(
      isSelected: isSelected,
      onTap: onTap,
      expand: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: isSelected
                  ? shad.colorScheme.primary.withValues(alpha: 0.12)
                  : shad.colorScheme.secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Icon(
              _themeStyleIcon(style),
              size: 18,
              color: isSelected
                  ? shad.colorScheme.primary
                  : shad.colorScheme.foreground,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.label,
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  style.description,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              LucideIcons.check,
              size: 18,
              color: shad.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return InteractiveSurfaceCard(
      isSelected: isSelected,
      onTap: onTap,
      expand: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? shad.colorScheme.primary.withValues(alpha: 0.14)
                  : shad.colorScheme.secondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Icon(
              _themeModeIcon(mode),
              size: 18,
              color: isSelected
                  ? shad.colorScheme.primary
                  : shad.colorScheme.foreground,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label,
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _getDescription(mode),
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(LucideIcons.check, size: 18, color: shad.colorScheme.primary),
        ],
      ),
    );
  }

  String _getDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '界面更轻盈，适合白天长时间工作';
      case AppThemeMode.dark:
        return '层级更聚焦，适合夜间或低光环境';
      case AppThemeMode.system:
        return '自动跟随系统切换，省心不折腾';
    }
  }
}

class _ThemeBackupHintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Icon(
              LucideIcons.database,
              size: 18,
              color: shad.colorScheme.primary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题设置会随备份一起保存',
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '你在这里挑好的风格和色调，会被一起写入备份文件，换机或恢复时不用重新配一遍。',
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
