# 彻底移除 Material 依赖计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将项目从 Flutter Material 迁移到纯 shadcn_ui 实现，统一 UI 框架，消除风格不一致问题

**Architecture:** 使用 shadcn_ui 提供的组件替代 Material 组件，对于 shadcn_ui 没有直接替代的组件（如 Scaffold、Navigator），使用自定义实现或保留必要的最小依赖

**Tech Stack:** shadcn_ui, lucide_icons_flutter

---

## 当前 Material 使用分析

### Material 组件使用情况

| Material 组件 | 使用次数 | shadcn_ui 替代方案 | 迁移难度 |
|--------------|---------|-------------------|---------|
| Scaffold | 14 | 自定义 Scaffold 或保留 | 中 |
| Navigator | 20+ | 保留（框架级） | 低 |
| Material | 1 | Container | 低 |
| CircularProgressIndicator | 2 | ShadProgress | 低 |
| SegmentedButton | 2 | 自定义或 ShadSelect | 中 |
| IconButton | 少 | ShadButton.ghost | 低 |
| TextField | 少 | ShadInput | 低 |
| Switch | 1 | ShadSwitch | 低 |
| showDialog | 少 | ShadDialog | 低 |

### 需要保留的 Material 依赖

1. **Navigator** - Flutter 框架级导航，shadcn_ui 没有替代
2. **Scaffold** - 基础布局结构，shadcn_ui 没有直接替代
3. **MaterialLocalizations** - 国际化支持
4. **ThemeData** - 某些组件可能需要

### 可以完全移除的 Material 使用

1. `import 'package:flutter/material.dart' hide Typography` - 改为具体导入
2. `Material` widget - 改为 Container
3. `CircularProgressIndicator` - 改为 ShadProgress 或自定义
4. `SegmentedButton` - 改为自定义实现
5. `IconButton` - 改为 ShadButton.ghost
6. `TextField` - 改为 ShadInput

---

## 文件结构

### 新增文件

```
lib/
  core/
    widgets/
      custom_scaffold.dart       # 自定义 Scaffold 实现
      custom_progress.dart       # 自定义进度指示器
      custom_segmented_button.dart # 自定义分段按钮
      custom_show_dialog.dart    # 自定义对话框
```

### 修改文件

```
lib/app.dart
lib/main.dart
lib/core/router/app_router.dart
lib/core/router/app_navigation.dart
lib/core/widgets/page_header.dart
lib/core/widgets/surface_cards.dart
lib/core/widgets/loading_widgets.dart
lib/core/animations/animation_builders.dart
lib/core/design_tokens/shadows.dart
lib/core/design_tokens/typography.dart
lib/core/tools/tool_registry.dart
lib/core/tools/tool_descriptor.dart
lib/core/system/app_tray_service.dart
lib/features/settings/presentation/autostart_settings_page.dart
lib/features/settings/presentation/theme_settings_page.dart
lib/features/settings/presentation/settings_page.dart
lib/features/settings/presentation/backup_settings_page.dart
lib/features/settings/domain/app_theme_style.dart
lib/features/settings/domain/theme_mode.dart
lib/features/settings/data/theme_service.dart
lib/features/hotkey_settings/presentation/hotkey_settings_page.dart
lib/features/hotkey_settings/domain/hotkey_action_descriptor.dart
lib/features/scheduler/presentation/scheduler_page.dart
lib/features/scheduler/presentation/task_editor_page.dart
lib/features/scheduler/presentation/task_logs_page.dart
lib/features/home/presentation/home_page.dart
lib/features/folder_mapping/presentation/folder_mapping_page.dart
lib/features/json_formatter/presentation/json_formatter_page.dart
lib/features/json_formatter/presentation/widgets/json_code_editor.dart
lib/features/json_formatter/presentation/widgets/json_toolbar.dart
lib/features/backup_restore/presentation/backup_restore_page.dart
lib/core/themes/modern_theme.dart
lib/core/themes/luxury_theme.dart
```

---

## 实施任务

### Task 1: 创建自定义 Scaffold 组件

**Files:**
- Create: `lib/core/widgets/custom_scaffold.dart`

- [ ] **Step 1: 创建 CustomScaffold**

```dart
// lib/core/widgets/custom_scaffold.dart
import 'package:flutter/material.dart' show Brightness, Colors;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 自定义 Scaffold，替代 Material Scaffold
/// 提供基础布局结构，不依赖 Material
class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final bgColor = backgroundColor ?? shad.colorScheme.background;

    return ColoredBox(
      color: bgColor,
      child: Column(
        children: [
          if (appBar != null) appBar!,
          Expanded(
            child: body,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/custom_scaffold.dart
git commit -m "feat: create CustomScaffold widget to replace Material Scaffold"
```

---

### Task 2: 创建自定义进度指示器

**Files:**
- Create: `lib/core/widgets/custom_progress.dart`

- [ ] **Step 1: 创建进度指示器组件**

```dart
// lib/core/widgets/custom_progress.dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 自定义圆形进度指示器，替代 Material CircularProgressIndicator
class CustomCircularProgressIndicator extends StatefulWidget {
  const CustomCircularProgressIndicator({
    super.key,
    this.size = 20,
    this.strokeWidth = 2,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<CustomCircularProgressIndicator> createState() =>
      _CustomCircularProgressIndicatorState();
}

class _CustomCircularProgressIndicatorState
    extends State<CustomCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final color = widget.color ?? shad.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CircularProgressPainter(
              progress: _controller.value,
              color: color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 背景圆环
    canvas.drawCircle(
      center,
      radius,
      paint..color = color.withValues(alpha: 0.2),
    );

    // 进度弧
    final sweepAngle = 2 * math.pi * 0.75;
    final startAngle = -math.pi / 2 + (2 * math.pi * progress);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 自定义线性进度指示器
class CustomLinearProgressIndicator extends StatelessWidget {
  const CustomLinearProgressIndicator({
    super.key,
    this.value,
    this.height = 4,
    this.color,
    this.backgroundColor,
  });

  final double? value;
  final double height;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final progressColor = color ?? shad.colorScheme.primary;
    final bgColor = backgroundColor ?? shad.colorScheme.secondary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value ?? 0,
        child: Container(
          decoration: BoxDecoration(
            color: progressColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/custom_progress.dart
git commit -m "feat: create custom progress indicators to replace Material"
```

---

### Task 3: 创建自定义分段按钮

**Files:**
- Create: `lib/core/widgets/custom_segmented_button.dart`

- [ ] **Step 1: 创建 SegmentedButton 替代**

```dart
// lib/core/widgets/custom_segmented_button.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 自定义分段按钮，替代 Material SegmentedButton
class CustomSegmentedButton<T> extends StatelessWidget {
  const CustomSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<CustomButtonSegment<T>> segments;
  final Set<T> selected;
  final void Function(Set<T>) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: shad.colorScheme.secondary,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: shad.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = selected.contains(segment.value);
          return _buildSegment(context, shad, segment, isSelected);
        }).toList(),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    ShadThemeData shad,
    CustomButtonSegment<T> segment,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        final newSelection = <T>{segment.value};
        onSelectionChanged(newSelection);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? shad.colorScheme.primary : null,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.icon != null) ...[
              Icon(
                segment.icon,
                size: 16,
                color: isSelected
                    ? shad.colorScheme.primaryForeground
                    : shad.colorScheme.foreground,
              ),
              const SizedBox(width: Spacing.xs),
            ],
            Text(
              segment.label,
              style: Typography.label.copyWith(
                color: isSelected
                    ? shad.colorScheme.primaryForeground
                    : shad.colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButtonSegment<T> {
  const CustomButtonSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/custom_segmented_button.dart
git commit -m "feat: create CustomSegmentedButton to replace Material"
```

---

### Task 4: 创建自定义对话框工具

**Files:**
- Create: `lib/core/widgets/custom_show_dialog.dart`

- [ ] **Step 1: 创建对话框工具函数**

```dart
// lib/core/widgets/custom_show_dialog.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 显示自定义对话框，替代 Material showDialog
Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? const Color(0x80000000),
    transitionDuration: AnimationDuration.dialogTransition,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
  );
}

/// 显示确认对话框
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = '确认',
  String cancelText = '取消',
  bool isDestructive = false,
}) {
  final shad = ShadTheme.of(context);

  return showCustomDialog<bool>(
    context: context,
    builder: (context) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: shad.colorScheme.card,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            border: Border.all(color: shad.colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Typography.h4.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                content,
                style: Typography.body.copyWith(
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelText),
                  ),
                  const SizedBox(width: Spacing.sm),
                  isDestructive
                      ? ShadButton.destructive(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(confirmText),
                        )
                      : ShadButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(confirmText),
                        ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 显示输入对话框
Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  String? initialValue,
  String confirmText = '确认',
  String cancelText = '取消',
  String? Function(String?)? validator,
}) {
  final shad = ShadTheme.of(context);
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();

  return showCustomDialog<String>(
    context: context,
    builder: (context) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: shad.colorScheme.card,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            border: Border.all(color: shad.colorScheme.border),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Typography.h4.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                ShadInput(
                  controller: controller,
                  hintText: hintText,
                  validator: validator,
                ),
                const SizedBox(height: Spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.outline(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(cancelText),
                    ),
                    const SizedBox(width: Spacing.sm),
                    ShadButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(context).pop(controller.text);
                        }
                      },
                      child: Text(confirmText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/custom_show_dialog.dart
git commit -m "feat: create custom dialog utilities to replace Material"
```

---

### Task 5: 修改核心组件移除 Material 依赖

**Files:**
- Modify: `lib/core/widgets/page_header.dart`
- Modify: `lib/core/widgets/loading_widgets.dart`
- Modify: `lib/core/widgets/surface_cards.dart`

- [ ] **Step 1: 修改 page_header.dart**

```dart
// lib/core/widgets/page_header.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

/// 统一的页面顶部导航栏，替代 Material AppBar。
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: shad.colorScheme.background,
        border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
        boxShadow: Shadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        children: [
          if (showBack) ...[
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.arrowLeft, size: 15),
                  SizedBox(width: 4),
                  Text('返回'),
                ],
              ),
            ),
            Container(
              height: Spacing.md,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
              color: shad.colorScheme.border,
            ),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Typography.h4.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 修改 loading_widgets.dart**

```dart
// lib/core/widgets/loading_widgets.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';
import 'custom_progress.dart';

/// 空状态组件
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: shad.colorScheme.mutedForeground,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            title,
            style: Typography.h4.copyWith(
              color: shad.colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            description,
            style: Typography.body.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: Spacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// 加载指示器组件
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 20,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomCircularProgressIndicator(
            size: size,
            color: shad.colorScheme.primary,
          ),
          if (message != null) ...[
            const SizedBox(height: Spacing.md),
            Text(
              message!,
              style: Typography.body.copyWith(
                color: shad.colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/
git commit -m "refactor: remove Material from core widgets"
```

---

### Task 6: 修改工具注册和描述移除 Material

**Files:**
- Modify: `lib/core/tools/tool_descriptor.dart`
- Modify: `lib/core/tools/tool_registry.dart`

- [ ] **Step 1: 修改 tool_descriptor.dart**

```dart
// lib/core/tools/tool_descriptor.dart
import 'package:flutter/widgets.dart';

/// 工具描述符，定义工具的基本属性
class ToolDescriptor {
  const ToolDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.builder,
    this.windowSize,
    this.minWindowSize,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final WidgetBuilder builder;
  final Size? windowSize;
  final Size? minWindowSize;
}
```

- [ ] **Step 2: 修改 tool_registry.dart**

```dart
// lib/core/tools/tool_registry.dart
import 'package:flutter/widgets.dart';

import '../../features/folder_mapping/presentation/folder_mapping_page.dart';
import '../../features/json_formatter/presentation/json_formatter_page.dart';
import '../../features/scheduler/presentation/scheduler_page.dart';
import '../router/app_routes.dart';
import 'tool_descriptor.dart';

class ToolRegistry {
  ToolRegistry._();

  static final List<ToolDescriptor> tools = [
    ToolDescriptor(
      id: 'scheduler',
      title: '定时任务',
      description: '按时间与周期执行命令',
      icon: const IconData(0xe389, fontFamily: 'MaterialIcons'),  // Icons.schedule
      route: AppRoutes.scheduler,
      builder: (_) => const SchedulerPage(),
      windowSize: const Size(950, 700),
      minWindowSize: const Size(800, 550),
    ),
    ToolDescriptor(
      id: 'folder_mapping',
      title: '文件夹映射',
      description: '快捷管理并双击打开目录',
      icon: const IconData(0xe2c7, fontFamily: 'MaterialIcons'),  // Icons.folder_copy_outlined
      route: AppRoutes.folderMapping,
      builder: (_) => const FolderMappingPage(),
    ),
    ToolDescriptor(
      id: 'json_formatter',
      title: 'JSON 格式化',
      description: '格式化、压缩、转义及智能修复JSON数据',
      icon: const IconData(0xe3c8, fontFamily: 'MaterialIcons'),  // Icons.data_object
      route: AppRoutes.jsonFormatter,
      builder: (_) => const JsonFormatterPage(),
      windowSize: const Size(1000, 700),
      minWindowSize: const Size(800, 550),
    ),
  ];

  static ToolDescriptor? findById(String id) {
    return tools.where((t) => t.id == id).firstOrNull;
  }
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/tools/
git commit -m "refactor: remove Material from tool registry"
```

---

### Task 7: 修改主题文件移除 Material

**Files:**
- Modify: `lib/core/themes/modern_theme.dart`
- Modify: `lib/core/themes/luxury_theme.dart`
- Modify: `lib/features/settings/domain/app_theme_style.dart`
- Modify: `lib/features/settings/domain/theme_mode.dart`
- Modify: `lib/features/settings/data/theme_service.dart`

- [ ] **Step 1: 修改 modern_theme.dart**

```dart
// lib/core/themes/modern_theme.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ModernTheme {
  ModernTheme._();

  static ShadThemeData light() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFF8F9FE),
        foreground: Color(0xFF1A1A2E),
        cardForeground: Color(0xFF1A1A2E),
        primary: Color(0xFF6366F1),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFEEF2FF),
        secondaryForeground: Color(0xFF4338CA),
        muted: Color(0xFFF1F5F9),
        mutedForeground: Color(0xFF64748B),
        accent: Color(0xFFEEF2FF),
        accentForeground: Color(0xFF4338CA),
        border: Color(0xFFE2E8F0),
        input: Color(0xFFE2E8F0),
        ring: Color(0xFF6366F1),
        selection: Color(0xFFC7D2FE),
      ),
      radius: BorderRadius.circular(12),
    );
  }

  static ShadThemeData dark() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF0F0F1A),
        foreground: Color(0xFFE2E8F0),
        card: Color(0xFF1A1A2E),
        cardForeground: Color(0xFFE2E8F0),
        primary: Color(0xFF818CF8),
        primaryForeground: Color(0xFF0F0F1A),
        secondary: Color(0xFF1E1B4B),
        secondaryForeground: Color(0xFFA5B4FC),
        muted: Color(0xFF1E293B),
        mutedForeground: Color(0xFF94A3B8),
        accent: Color(0xFF1E1B4B),
        accentForeground: Color(0xFFA5B4FC),
        border: Color(0xFF2D2B5E),
        input: Color(0xFF2D2B5E),
        ring: Color(0xFF818CF8),
        selection: Color(0xFF3730A3),
      ),
      radius: BorderRadius.circular(12),
    );
  }
}
```

- [ ] **Step 2: 修改 theme_mode.dart**

```dart
// lib/features/settings/domain/theme_mode.dart
import 'package:flutter/widgets.dart';

enum AppThemeMode {
  light,
  dark,
  system;

  ThemeMode toFlutterThemeMode() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/themes/ lib/features/settings/domain/
git commit -m "refactor: remove Material from theme files"
```

---

### Task 8: 修改动画和设计令牌移除 Material

**Files:**
- Modify: `lib/core/animations/animation_builders.dart`
- Modify: `lib/core/design_tokens/shadows.dart`
- Modify: `lib/core/design_tokens/typography.dart`

- [ ] **Step 1: 修改 animation_builders.dart**

```dart
// lib/core/animations/animation_builders.dart
import 'package:flutter/widgets.dart';

/// 动画时长常量
class AnimationDuration {
  AnimationDuration._();

  static const Duration hoverEffect = Duration(milliseconds: 150);
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration dialogTransition = Duration(milliseconds: 200);
  static const Duration staggeredDelay = Duration(milliseconds: 50);
}

/// 页面过渡动画构建器
class PageTransitionBuilder {
  PageTransitionBuilder._();

  static Route<T> buildPageTransition<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));
        final fadeTween = Tween(begin: 0.0, end: 1.0);

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: AnimationDuration.pageTransition,
    );
  }
}

/// 交错动画构建器
class StaggeredAnimationBuilder extends StatelessWidget {
  const StaggeredAnimationBuilder({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AnimationDuration.pageTransition +
          (AnimationDuration.staggeredDelay * index),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
```

- [ ] **Step 2: 修改 shadows.dart**

```dart
// lib/core/design_tokens/shadows.dart
import 'package:flutter/widgets.dart';

/// 阴影设计令牌
class Shadows {
  Shadows._();

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0x0F000000),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0x14000000),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}
```

- [ ] **Step 3: 修改 typography.dart**

```dart
// lib/core/design_tokens/typography.dart
import 'package:flutter/widgets.dart';

/// 排版设计令牌
class Typography {
  Typography._();

  static const String _fontFamily = 'Inter';

  static TextStyle get h1 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get h2 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
      );

  static TextStyle get h3 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get h4 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.57,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
      );

  static TextStyle get label => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.33,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );
}
```

- [ ] **Step 4: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/ lib/core/design_tokens/
git commit -m "refactor: remove Material from animations and design tokens"
```

---

### Task 9: 修改路由和导航移除 Material

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/router/app_navigation.dart`

- [ ] **Step 1: 修改 app_router.dart**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/widgets.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../tools/tool_registry.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.home) {
      return _buildRoute(const HomePage(), settings);
    }

    if (settings.name == AppRoutes.settings) {
      return _buildRoute(const SettingsPage(), settings);
    }

    final tool = ToolRegistry.tools
        .where((t) => t.route == settings.name)
        .firstOrNull;
    if (tool != null) {
      return _buildRoute(tool.builder(_FakeContext()), settings);
    }

    return _buildRoute(
      const _NotFoundPage(),
      settings,
    );
  }

  static Route<dynamic> _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));
        final fadeTween = Tween(begin: 0.0, end: 1.0);

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('页面不存在'),
    );
  }
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/
git commit -m "refactor: remove Material from router"
```

---

### Task 10: 修改所有页面移除 Material

**Files:**
- Modify: `lib/features/home/presentation/home_page.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Modify: `lib/features/settings/presentation/theme_settings_page.dart`
- Modify: `lib/features/settings/presentation/autostart_settings_page.dart`
- Modify: `lib/features/settings/presentation/backup_settings_page.dart`
- Modify: `lib/features/scheduler/presentation/scheduler_page.dart`
- Modify: `lib/features/scheduler/presentation/task_editor_page.dart`
- Modify: `lib/features/scheduler/presentation/task_logs_page.dart`
- Modify: `lib/features/hotkey_settings/presentation/hotkey_settings_page.dart`
- Modify: `lib/features/folder_mapping/presentation/folder_mapping_page.dart`
- Modify: `lib/features/json_formatter/presentation/json_formatter_page.dart`
- Modify: `lib/features/json_formatter/presentation/widgets/json_code_editor.dart`
- Modify: `lib/features/json_formatter/presentation/widgets/json_toolbar.dart`
- Modify: `lib/features/backup_restore/presentation/backup_restore_page.dart`

- [ ] **Step 1: 修改 home_page.dart**

将 `import 'package:flutter/material.dart' hide Typography;` 改为具体导入：
```dart
import 'package:flutter/widgets.dart';
```

将 `Scaffold` 改为 `CustomScaffold`

- [ ] **Step 2: 修改其余页面**

按照相同模式修改所有页面：
1. 替换 Material 导入为具体导入
2. 替换 Scaffold 为 CustomScaffold
3. 替换 CircularProgressIndicator 为 CustomCircularProgressIndicator
4. 替换 SegmentedButton 为 CustomSegmentedButton

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/
git commit -m "refactor: remove Material from all feature pages"
```

---

### Task 11: 修改 app.dart 和 main.dart 移除 Material

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 修改 app.dart**

```dart
// lib/app.dart
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/router/app_navigation.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/tools/tool_registry.dart';
import 'features/settings/data/theme_service.dart';
import 'features/settings/domain/app_theme_style.dart';
import 'features/settings/domain/theme_mode.dart';

class ToolboxApp extends StatefulWidget {
  const ToolboxApp({super.key, this.toolId});

  final String? toolId;

  @override
  State<ToolboxApp> createState() => _ToolboxAppState();
}

class _ToolboxAppState extends State<ToolboxApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final service = ThemeService.instance;

    return ValueListenableBuilder<AppThemeStyle>(
      valueListenable: service.currentStyle,
      builder: (context, style, _) {
        return ValueListenableBuilder<AppThemeMode>(
          valueListenable: service.currentMode,
          builder: (context, mode, _) {
            final brightness = _resolveBrightness(mode);
            final themeData = service.getThemeData(style, brightness);

            return ShadApp(
              title: widget.toolId != null
                  ? (ToolRegistry.findById(widget.toolId!)?.title ?? '工具集')
                  : 'Windows 工具集',
              theme: themeData,
              themeMode: mode.toFlutterThemeMode(),
              home: widget.toolId != null
                  ? ToolRegistry.findById(widget.toolId!)?.builder(context)
                  : null,
              navigatorKey: widget.toolId == null ? appNavigatorKey : null,
              onGenerateRoute: widget.toolId == null
                  ? AppRouter.onGenerateRoute
                  : null,
              initialRoute: widget.toolId == null ? AppRoutes.home : null,
            );
          },
        );
      },
    );
  }

  Brightness _resolveBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }
}
```

- [ ] **Step 2: 修改 main.dart**

移除 `import 'package:flutter/material.dart';`，改为：
```dart
import 'package:flutter/widgets.dart';
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart lib/main.dart
git commit -m "refactor: remove Material from app entry points"
```

---

### Task 12: 运行测试验证

**Files:**
- Test: `test/widget_test.dart`
- Test: `test/visual/*.dart`

- [ ] **Step 1: 运行 flutter analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: 运行 flutter test**

Run: `flutter test`
Expected: 所有测试通过

- [ ] **Step 3: 修复失败的测试（如有）**

根据测试失败原因进行修复

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: fix tests after Material removal"
```

---

## 执行顺序建议

1. Task 1-4: 创建自定义组件（可并行）
2. Task 5-9: 修改核心组件（可并行）
3. Task 10-11: 修改页面和入口
4. Task 12: 测试验证

## 注意事项

1. **渐进式迁移**：可以先保留 Material 导入，逐步替换组件
2. **测试策略**：每修改一个组件就运行测试，确保不破坏现有功能
3. **Navigator 保留**：Navigator 是框架级组件，暂时保留
4. **字体图标**：Material Icons 可以保留，因为它们是字体图标，不依赖 Material 组件

## 风险评估

1. **ShadApp 依赖**：ShadApp 可能内部依赖 Material，需要检查
2. **国际化支持**：MaterialLocalizations 可能需要保留
3. **某些组件无替代**：如 Scaffold、Navigator 等可能需要保留最小依赖
