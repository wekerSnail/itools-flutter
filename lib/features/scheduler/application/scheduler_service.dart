import 'package:flutter/foundation.dart';

import '../data/scheduler_store.dart';
import '../domain/scheduled_task.dart';

class SchedulerService {
  final SchedulerStore _store = SchedulerStore();

  Future<List<ScheduledTask>> loadTasks() async {
    final loaded = await _store.loadTasks();
    debugPrint('[SchedulerService] Loaded ${loaded.length} tasks');
    return loaded;
  }

  Future<void> saveTasks(List<ScheduledTask> tasks) async {
    await _store.saveTasks(tasks);
    debugPrint('[SchedulerService] Saved ${tasks.length} tasks');
  }
}
