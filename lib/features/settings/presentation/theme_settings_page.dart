import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../data/theme_service.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  final _service = ThemeService.instance;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '主题设置',
        subtitle: '选择视觉风格和色调',
        showBack: true,
      ),
      body: ValueListenableBuilder<AppThemeStyle>(
        valueListenable: _service.currentStyle,
        builder: (context, currentStyle, _) {
          return ValueListenableBuilder<AppThemeMode>(
            valueListenable: _service.currentMode,
            builder: (context, currentMode, __) {
              return ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  _ThemeOverviewCard(
                    currentStyle: currentStyle,
                    currentMode: currentMode,
                  ),
                  const SizedBox(height: Spacing.xl),
                  const PageSectionHeader(
                    title: '主题风格库',
                    subtitle: '统一的卡片语言配上各自不同的气质表达，选一个最对胃口的工作氛围。',
                    icon: Icons.palette_outlined,
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
                                  isSelected: style == currentStyle,
                                  onTap: () => _service.setThemeStyle(style),
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
                    subtitle: '亮、暗、跟随系统三种模式统一采用同一套选择器语言，不再像三个走散的按钮。',
                    icon: Icons.brightness_6_outlined,
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
                                  isSelected: mode == currentMode,
                                  onTap: () => _service.setThemeMode(mode),
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                  const SizedBox(height: Spacing.xl),
                  const PageSectionHeader(
                    title: '实时预览',
                    subtitle: '用一块轻量级样板区，直接感受当前主题在按钮、信息层级和表面层次上的状态。',
                    icon: Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(height: Spacing.md),
                  _ThemeLivePreviewCard(
                    currentStyle: currentStyle,
                    currentMode: currentMode,
                  ),
                  const SizedBox(height: Spacing.md),
                  _ThemeBackupHintCard(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ThemeOverviewCard extends StatelessWidget {
  const _ThemeOverviewCard({
    required this.currentStyle,
    required this.currentMode,
  });

  final AppThemeStyle currentStyle;
  final AppThemeMode currentMode;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageSectionHeader(
            title: '当前配置',
            subtitle: '先看现在是什么，再决定要不要把界面变得更稳、更亮或者更有个性。',
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              ShadBadge.secondary(child: Text('风格 · ${currentStyle.label}')),
              ShadBadge.secondary(child: Text('模式 · ${currentMode.label}')),
              ShadBadge.secondary(child: Text(_buildMoodLabel(currentStyle))),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            currentStyle.description,
            style: Typography.body.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  String _buildMoodLabel(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.modern:
        return '专业清爽';
      case AppThemeStyle.luxury:
        return '克制优雅';
      case AppThemeStyle.stellar:
        return '锐利高能';
      case AppThemeStyle.aurora:
        return '自然高级';
      case AppThemeStyle.sunset:
        return '温暖沉稳';
    }
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
      padding: EdgeInsets.zero,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThemePalettePreview(style: style),
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
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
                    style.icon,
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
                    Icons.check_circle,
                    size: 18,
                    color: shad.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePalettePreview extends StatelessWidget {
  const _ThemePalettePreview({required this.style});

  final AppThemeStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = style.previewColors;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(BorderRadiusTokens.lg - 1),
      ),
      child: Container(
        height: 156,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.first.withValues(alpha: 0.18),
              colors[1].withValues(alpha: 0.1),
              colors.last.withValues(alpha: 0.22),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: colors
                  .map(
                    (color) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: Spacing.xs),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(
                        BorderRadiusTokens.sm,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[1].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        BorderRadiusTokens.sm,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Container(
                    width: 180,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.last.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(
                        BorderRadiusTokens.sm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              mode.icon,
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
            Icon(Icons.check_circle, size: 18, color: shad.colorScheme.primary),
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

class _ThemeLivePreviewCard extends StatelessWidget {
  const _ThemeLivePreviewCard({
    required this.currentStyle,
    required this.currentMode,
  });

  final AppThemeStyle currentStyle;
  final AppThemeMode currentMode;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final colors = currentStyle.previewColors;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前主题小样板',
                      style: Typography.label.copyWith(
                        color: shad.colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      '${currentStyle.label} · ${currentMode.label}',
                      style: Typography.bodySmall.copyWith(
                        color: shad.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: Spacing.xs,
                children: colors
                    .map(
                      (color) => Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工作台标题',
                  style: Typography.h4.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '这是对当前主题层级、表面和重点色的快速预览，不必切出页面也能判断是否顺眼。',
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    ShadButton(onPressed: () {}, child: const Text('主操作')),
                    const SizedBox(width: Spacing.sm),
                    ShadButton.ghost(
                      onPressed: () {},
                      child: const Text('次操作'),
                    ),
                    const Spacer(),
                    ShadBadge.secondary(child: Text(currentStyle.label)),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: shad.colorScheme.background,
                    border: Border.all(color: shad.colorScheme.border),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: shad.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          '搜索设置项、任务或文件映射',
                          style: Typography.bodySmall.copyWith(
                            color: shad.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],
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
              Icons.backup_outlined,
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
