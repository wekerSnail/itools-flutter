import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scheduler/application/task_runner.dart';
import '../../features/scheduler/domain/scheduled_task.dart';

class TaskRunnerNotifier extends Notifier<TaskRunner> {
  @override
  TaskRunner build() {
    final runner = TaskRunner();
    ref.onDispose(() => runner.dispose());
    return runner;
  }

  void start({required List<ScheduledTask> Function() tasksProvider}) {
    state.start(tasksProvider: tasksProvider);
  }

  Future<void> runNow(ScheduledTask task) async {
    await state.runNow(task);
  }

  void stop() {
    state.stop();
  }
}

final taskRunnerProvider =
    NotifierProvider<TaskRunnerNotifier, TaskRunner>(TaskRunnerNotifier.new);

final logsProvider = Provider<ValueNotifier<List<String>>>((ref) {
  final runner = ref.watch(taskRunnerProvider);
  return runner.logs;
});
