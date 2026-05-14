import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scheduler/application/task_runner.dart';
import '../../features/scheduler/domain/scheduled_task.dart';
import 'scheduler_provider.dart';

class TaskRunnerNotifier extends Notifier<TaskRunner> {
  @override
  TaskRunner build() {
    final runner = TaskRunner();
    ref.onDispose(() => runner.dispose());
    return runner;
  }

  Future<void> start({
    required List<ScheduledTask> Function() tasksProvider,
  }) async {
    await state.start(tasksProvider: tasksProvider);
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

/// Ensures tasks are loaded and the automatic scheduler is running.
/// Watch this provider once at app startup to bootstrap the scheduler.
final schedulerBootstrapProvider = Provider<bool>((ref) {
  ref.listen<AsyncValue<List<ScheduledTask>>>(schedulerProvider, (_, next) {
    next.whenData((tasks) async {
      debugPrint(
        '[SchedulerBootstrap] Loaded ${tasks.length} tasks, starting runner',
      );
      await ref.read(taskRunnerProvider.notifier).start(
        tasksProvider: () =>
            ref.read(schedulerProvider).value ?? <ScheduledTask>[],
      );
    });
  });

  // Ensure tasks are loaded (build() already loads them, but trigger reload
  // in case the provider was already built before this listener was attached)
  ref.read(schedulerProvider.notifier).reload();

  return true;
});
