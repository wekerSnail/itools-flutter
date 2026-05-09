import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '视觉风格',
            style: shad.textTheme.large.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择不同的视觉风格主题',
            style: shad.textTheme.muted,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<AppThemeStyle>(
            valueListenable: _service.currentStyle,
            builder: (context, currentStyle, _) {
              return Column(
                children: AppThemeStyle.values.map((style) {
                  final isSelected = style == currentStyle;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ThemeStyleCard(
                      style: style,
                      isSelected: isSelected,
                      onTap: () => _service.setThemeStyle(style),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            '色调',
            style: shad.textTheme.large.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '选择亮色、暗色或跟随系统',
            style: shad.textTheme.muted,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<AppThemeMode>(
            valueListenable: _service.currentMode,
            builder: (context, currentMode, _) {
              return Column(
                children: AppThemeMode.values.map((mode) {
                  final isSelected = mode == currentMode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ThemeModeCard(
                      mode: mode,
                      isSelected: isSelected,
                      onTap: () => _service.setThemeMode(mode),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeStyleCard extends StatefulWidget {
  const _ThemeStyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThemeStyleCard> createState() => _ThemeStyleCardState();
}

class _ThemeStyleCardState extends State<_ThemeStyleCard> {
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
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: shad.colorScheme.card,
            border: Border.all(
              color: widget.isSelected
                  ? shad.colorScheme.primary
                  : _hovered
                      ? shad.colorScheme.ring
                      : shad.colorScheme.border,
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_hovered || widget.isSelected)
                BoxShadow(
                  color: shad.colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreview(shad),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.style.icon,
                      size: 20,
                      color: widget.isSelected
                          ? shad.colorScheme.primary
                          : shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.style.label,
                            style: shad.textTheme.large.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.style.description,
                            style: shad.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 24,
                        color: shad.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ShadThemeData shad) {
    switch (widget.style) {
      case AppThemeStyle.modern:
        return _buildModernPreview(shad);
      case AppThemeStyle.luxury:
        return _buildLuxuryPreview(shad);
    }
  }

  Widget _buildModernPreview(ShadThemeData shad) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: Container(
        height: 120,
        color: const Color(0xFFF0F4FF),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Text(
                  '优雅蓝色',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 16,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildLuxuryPreview(ShadThemeData shad) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: Container(
        height: 120,
        color: const Color(0xFFFAF8F5),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE5DDD5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B7355).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  '米灰优雅',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 16,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B7355).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8B7355).withOpacity(0.2),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7355).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7355).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
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

class _ThemeModeCard extends StatefulWidget {
  const _ThemeModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThemeModeCard> createState() => _ThemeModeCardState();
}

class _ThemeModeCardState extends State<_ThemeModeCard> {
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
              color: widget.isSelected
                  ? shad.colorScheme.primary
                  : _hovered
                      ? shad.colorScheme.ring
                      : shad.colorScheme.border,
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? shad.colorScheme.primary
                      : shad.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.mode.icon,
                  size: 18,
                  color: widget.isSelected
                      ? shad.colorScheme.primaryForeground
                      : shad.colorScheme.secondaryForeground,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mode.label,
                      style: shad.textTheme.p.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDescription(widget.mode),
                      style: shad.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: shad.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '始终使用亮色主题';
      case AppThemeMode.dark:
        return '始终使用暗色主题';
      case AppThemeMode.system:
        return '自动匹配系统主题设置';
    }
  }
}
