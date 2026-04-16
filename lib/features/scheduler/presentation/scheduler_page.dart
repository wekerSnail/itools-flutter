import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../application/task_runner.dart';
import '../data/scheduler_store.dart';
import '../domain/scheduled_task.dart';
import 'task_editor_page.dart';
import 'task_logs_page.dart';

class SchedulerPage extends StatefulWidget {
  const SchedulerPage({super.key});

  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  final SchedulerStore _store = SchedulerStore();
  final List<ScheduledTask> _tasks = <ScheduledTask>[];
  final Set<String> _runningTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    TaskRunner.instance.start(tasksProvider: () => _tasks);
  }

  Future<void> _load() async {
    final loaded = await _store.loadTasks();
    if (!mounted) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _openEditor({ScheduledTask? task}) async {
    final savedTask = await Navigator.of(context).push<ScheduledTask>(
      MaterialPageRoute(builder: (_) => TaskEditorPage(initialTask: task)),
    );
    if (savedTask == null || !mounted) return;
    final idx = _tasks.indexWhere((e) => e.id == savedTask.id);
    setState(() {
      if (idx >= 0) {
        _tasks[idx] = savedTask;
      } else {
        _tasks.insert(0, savedTask);
      }
    });
    await _store.saveTasks(_tasks);
  }

  Future<void> _toggleTask(ScheduledTask task, bool enabled) async {
    final idx = _tasks.indexWhere((e) => e.id == task.id);
    if (idx < 0) return;
    setState(() => _tasks[idx] = task.copyWith(enabled: enabled));
    await _store.saveTasks(_tasks);
  }

  Future<void> _deleteTask(ScheduledTask task) async {
    setState(() => _tasks.removeWhere((e) => e.id == task.id));
    await _store.saveTasks(_tasks);
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
      await TaskRunner.instance.runNow(task);
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
    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '定时任务',
        showBack: true,
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TaskLogsPage())),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText, size: 15),
                SizedBox(width: 6),
                Text('运行日志'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            size: ShadButtonSize.sm,
            onPressed: () => _openEditor(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 15),
                SizedBox(width: 6),
                Text('添加任务'),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _tasks.isEmpty
          ? _buildEmptyState(shad)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _tasks.length,
              itemBuilder: (_, i) => _buildTaskCard(context, shad, _tasks[i]),
            ),
    );
  }

  Widget _buildEmptyState(ShadThemeData shad) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.calendarClock,
              size: 36,
              color: shad.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          Text('暂无定时任务', style: shad.textTheme.large),
          const SizedBox(height: 6),
          Text('点击右上角"添加任务"开始创建', style: shad.textTheme.muted),
          const SizedBox(height: 20),
          ShadButton(
            onPressed: () => _openEditor(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 15),
                SizedBox(width: 6),
                Text('添加任务'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    ShadThemeData shad,
    ScheduledTask task,
  ) {
    final isRunning = _runningTaskIds.contains(task.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCard(
        padding: const EdgeInsets.all(16),
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
                        style: shad.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadBadge.secondary(
                        child: Text(_taskTypeLabel(task.type)),
                      ),
                      if (!task.enabled) ...[
                        const SizedBox(width: 6),
                        ShadBadge.outline(child: const Text('已停用')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    task.type == ScheduledTaskType.jsScript
                        ? (task.script ?? '').split('\n').first
                        : task.command,
                    style: shad.textTheme.muted.copyWith(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: shad.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDateTime(task.startAt)} · '
                        '每 ${task.intervalValue} ${_scheduleUnitLabel(task.intervalUnit)}',
                        style: shad.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.play, size: 15),
                ),
                ShadSwitch(
                  value: task.enabled,
                  onChanged: (v) => _toggleTask(task, v),
                ),
                const SizedBox(width: 4),
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
