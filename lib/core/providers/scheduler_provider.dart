import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scheduler/application/scheduler_service.dart';
import '../../features/scheduler/domain/scheduled_task.dart';

class SchedulerNotifier extends AsyncNotifier<List<ScheduledTask>> {
  final SchedulerService _service = SchedulerService();

  @override
  Future<List<ScheduledTask>> build() async {
    return _service.loadTasks();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.loadTasks());
  }

  Future<void> addTask(ScheduledTask task) async {
    final previous = state;
    final current = state.value ?? <ScheduledTask>[];
    state = AsyncData([task, ...current]);
    try {
      await _service.saveTasks(state.value!);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> updateTask(ScheduledTask task) async {
    final previous = state;
    final current = state.value ?? <ScheduledTask>[];
    final updated = current.map((e) => e.id == task.id ? task : e).toList();
    state = AsyncData(updated);
    try {
      await _service.saveTasks(state.value!);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> removeTask(String taskId) async {
    final previous = state;
    final current = state.value ?? <ScheduledTask>[];
    final updated = current.where((e) => e.id != taskId).toList();
    state = AsyncData(updated);
    try {
      await _service.saveTasks(state.value!);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final schedulerProvider =
    AsyncNotifierProvider<SchedulerNotifier, List<ScheduledTask>>(
  SchedulerNotifier.new,
);
