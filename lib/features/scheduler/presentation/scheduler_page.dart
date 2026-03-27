import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    TaskRunner.instance.start(tasksProvider: () => _tasks);
  }

  Future<void> _load() async {
    final loaded = await _store.loadTasks();
    if (!mounted) {
      return;
    }

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

    if (savedTask == null || !mounted) {
      return;
    }

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
    if (idx < 0) {
      return;
    }

    setState(() {
      _tasks[idx] = task.copyWith(enabled: enabled);
    });
    await _store.saveTasks(_tasks);
  }

  Future<void> _deleteTask(ScheduledTask task) async {
    setState(() => _tasks.removeWhere((e) => e.id == task.id));
    await _store.saveTasks(_tasks);
  }

  String _taskTypeLabel(ScheduledTaskType type) {
    switch (type) {
      case ScheduledTaskType.jsScript:
        return 'JS脚本';
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
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时任务'),
        actions: [
          IconButton(
            tooltip: '运行日志',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TaskLogsPage()));
            },
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('任务列表', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('添加任务'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('新增/编辑任务会在新页面打开；日志也在独立页面查看。'),
          const SizedBox(height: 16),
          if (_tasks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text('暂无任务，点击右上角“添加任务”开始创建。'),
                  ],
                ),
              ),
            )
          else
            ..._tasks.map(
              (task) => Card(
                child: ListTile(
                  title: Text(task.name),
                  subtitle: Text(
                    '${_taskTypeLabel(task.type)} | ${task.type == ScheduledTaskType.jsScript ? ((task.script ?? '').split('\n').first) : task.command}\n${_formatDateTime(task.startAt)} | 每 ${task.intervalValue} ${_scheduleUnitLabel(task.intervalUnit)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      Switch(
                        value: task.enabled,
                        onChanged: (v) => _toggleTask(task, v),
                      ),
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () => _openEditor(task: task),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _deleteTask(task),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
