import 'package:flutter/foundation.dart';

import '../data/scheduler_store.dart';
import '../domain/scheduled_task.dart';
import 'task_runner.dart';

class SchedulerService {
  SchedulerService._();

  static final SchedulerService instance = SchedulerService._();

  final SchedulerStore _store = SchedulerStore();
  final List<ScheduledTask> _tasks = <ScheduledTask>[];
  bool _initialized = false;

  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[SchedulerService] Already initialized, skipping');
      return;
    }

    debugPrint('[SchedulerService] Initializing...');
    await _loadTasks();

    TaskRunner.instance.start(tasksProvider: () => _tasks);
    _initialized = true;
    debugPrint('[SchedulerService] Initialized with ${_tasks.length} tasks');
  }

  Future<void> _loadTasks() async {
    try {
      final loaded = await _store.loadTasks();
      _tasks
        ..clear()
        ..addAll(loaded);
      debugPrint('[SchedulerService] Loaded ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[SchedulerService] Failed to load tasks: $e');
    }
  }

  Future<void> reloadTasks() async {
    await _loadTasks();
  }

  Future<void> saveTasks() async {
    try {
      await _store.saveTasks(_tasks);
      debugPrint('[SchedulerService] Saved ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[SchedulerService] Failed to save tasks: $e');
    }
  }

  void addTask(ScheduledTask task) {
    _tasks.insert(0, task);
  }

  void updateTask(ScheduledTask task) {
    final idx = _tasks.indexWhere((e) => e.id == task.id);
    if (idx >= 0) {
      _tasks[idx] = task;
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((e) => e.id == taskId);
  }

  void dispose() {
    TaskRunner.instance.dispose();
    _initialized = false;
  }
}
