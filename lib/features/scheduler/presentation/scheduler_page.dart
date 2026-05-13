import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/animations/animation_builders.dart';
import '../../../core/design_tokens/index.dart';
import '../../../core/providers/scheduler_provider.dart';
import '../../../core/providers/task_runner_provider.dart';
import '../../../core/widgets/custom_progress.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/loading_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../domain/scheduled_task.dart';
import 'task_editor_page.dart';
import 'task_logs_page.dart';

class SchedulerPage extends ConsumerStatefulWidget {
  const SchedulerPage({super.key});

  @override
  ConsumerState<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends ConsumerState<SchedulerPage> {
  final Set<String> _runningTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schedulerProvider.notifier).reload();
    });
  }

  Future<void> _openEditor({ScheduledTask? task}) async {
    final savedTask = await Navigator.of(context).push<ScheduledTask>(
      PageTransitionBuilder.buildPageTransition<ScheduledTask>(
        context: context,
        builder: (_) => TaskEditorPage(initialTask: task),
      ),
    );
    if (savedTask == null || !mounted) return;

    final notifier = ref.read(schedulerProvider.notifier);
    if (task != null) {
      await notifier.updateTask(savedTask);
    } else {
      await notifier.addTask(savedTask);
    }
  }

  Future<void> _toggleTask(ScheduledTask task, bool enabled) async {
    await ref
        .read(schedulerProvider.notifier)
        .updateTask(task.copyWith(enabled: enabled));
  }

  Future<void> _deleteTask(ScheduledTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('删除任务'),
          description: Text('确定要删除「${task.name}」吗？此操作不可撤销。'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ShadButton.destructive(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(schedulerProvider.notifier).removeTask(task.id);
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<void> _runTaskNow(ScheduledTask task) async {
    if (_runningTaskIds.contains(task.id)) {
      return;
    }

    setState(() => _runningTaskIds.add(task.id));
    _showToast('开始测试运行：${task.name}');

    try {
      await ref.read(taskRunnerProvider).runNow(task);
      if (!mounted) return;
      _showToast('任务已执行完成：${task.name}');
    } catch (error) {
      if (!mounted) return;
      _showToast('任务执行失败：$error');
    } finally {
      if (mounted) {
        setState(() => _runningTaskIds.remove(task.id));
      }
    }
  }

  String _taskTypeLabel(ScheduledTaskType type) {
    switch (type) {
      case ScheduledTaskType.jsScript:
        return 'JS 脚本';
      case ScheduledTaskType.terminalCommand:
        return '终端命令';
    }
  }

  String _scheduleUnitLabel(ScheduleUnit unit) {
    switch (unit) {
      case ScheduleUnit.second:
        return '秒';
      case ScheduleUnit.minute:
        return '分钟';
      case ScheduleUnit.hour:
        return '小时';
      case ScheduleUnit.day:
        return '天';
      case ScheduleUnit.week:
        return '周';
      case ScheduleUnit.month:
        return '月';
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final tasksAsync = ref.watch(schedulerProvider);

    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '定时任务',
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => Navigator.of(context).push(
              PageTransitionBuilder.buildPageTransition<void>(
                context: context,
                builder: (_) => const TaskLogsPage(),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText, size: 15),
                SizedBox(width: Spacing.xs),
                Text('运行日志'),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          ShadButton(
            size: ShadButtonSize.sm,
            onPressed: () => _openEditor(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 15),
                SizedBox(width: Spacing.xs),
                Text('添加任务'),
              ],
            ),
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CustomCircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _buildEmptyState(shad);
          }
          return ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              const PageSectionHeader(
                title: '任务总览',
                subtitle: '把定时任务的状态、频率和操作入口放在一套统一的列表语言里。',
                icon: LucideIcons.clock,
              ),
              const SizedBox(height: Spacing.md),
              ...tasks.asMap().entries.map(
                (entry) => StaggeredAnimationBuilder(
                  index: entry.key,
                  child: _buildTaskCard(context, shad, entry.value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ShadThemeData shad) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const PageSectionHeader(
          title: '任务总览',
          subtitle: '从这里创建、管理和快速运行任务，空状态也保持统一的桌面工具层级。',
          icon: LucideIcons.clock,
        ),
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: SizedBox(
            height: 320,
            child: EmptyStateWidget(
              icon: LucideIcons.calendarClock,
              title: '暂无定时任务',
              description: '点击右上角"添加任务"开始创建',
              action: ShadButton(
                onPressed: () => _openEditor(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 15),
                    SizedBox(width: Spacing.xs),
                    Text('添加任务'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    ShadThemeData shad,
    ScheduledTask task,
  ) {
    final isRunning = _runningTaskIds.contains(task.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: InteractiveSurfaceCard(
        expand: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        task.name,
                        style: Typography.label.copyWith(
                          color: shad.colorScheme.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      ShadBadge.secondary(
                        child: Text(_taskTypeLabel(task.type)),
                      ),
                      if (!task.enabled) ...[
                        const SizedBox(width: Spacing.xs),
                        const ShadBadge.outline(child: Text('已停用')),
                      ],
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    task.type == ScheduledTaskType.jsScript
                        ? (task.script ?? '').split('\n').first
                        : task.command,
                    style: Typography.caption.copyWith(
                      color: shad.colorScheme.mutedForeground,
                      fontFamily: 'Consolas',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: shad.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        '${_formatDateTime(task.startAt)} · '
                        '每 ${task.intervalValue} ${_scheduleUnitLabel(task.intervalUnit)}',
                        style: Typography.caption.copyWith(
                          color: shad.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: isRunning ? null : () => _runTaskNow(task),
                  child: isRunning
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CustomCircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.play, size: 15),
                ),
                ShadSwitch(
                  value: task.enabled,
                  onChanged: (v) => _toggleTask(task, v),
                ),
                const SizedBox(width: Spacing.xs),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => _openEditor(task: task),
                  child: const Icon(LucideIcons.pencil, size: 15),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => _deleteTask(task),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 15,
                    color: shad.colorScheme.destructive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
