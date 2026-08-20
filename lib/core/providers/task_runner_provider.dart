import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/file_store.dart';
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

  // 监听 tasks.json 变化（子窗口编辑 / 备份导入 / 外部修改），
  // 保证主引擎调度器始终使用最新任务定义，不会执行已禁用的任务。
  unawaited(_watchTasksFileForChanges(ref));

  // Ensure tasks are loaded (build() already loads them, but trigger reload
  // in case the provider was already built before this listener was attached).
  // Riverpod 禁止在 provider 初始化期间同步修改其他 provider 的状态，
  // 这里调度到下一个事件循环再触发 reload。
  unawaited(_reloadTasks(ref));

  return true;
});

Future<void> _reloadTasks(Ref ref) async {
  // 先让出当前同步调用栈：async 函数体在首个 await 前依然同步执行，
  // 直接 read/reload 仍处于 provider 初始化期，会触发 Riverpod 断言。
  await Future<void>.delayed(Duration.zero);
  try {
    await ref.read(schedulerProvider.notifier).reload();
  } catch (e) {
    debugPrint('[SchedulerBootstrap] Initial reload failed: $e');
  }
}

Future<void> _watchTasksFileForChanges(Ref ref) async {
  Stream<FileSystemEvent>? events;
  try {
    final basePath = await FileStore.basePath;
    // 监听目录而非单个文件：原子写入（临时文件 rename）只产生目录事件，
    // 监听文件路径本身会漏掉替换。
    events = Directory('$basePath/scheduler').watch();
  } catch (e) {
    debugPrint('[SchedulerBootstrap] Watch tasks.json failed: $e');
    return;
  }

  Timer? syncDebounce;
  final subscription = events.listen((event) {
    final path = event.path.replaceAll('\\', '/');
    if (!path.endsWith('scheduler/tasks.json')) {
      return;
    }
    syncDebounce?.cancel();
    syncDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_syncTasksFromDiskIfChanged(ref));
    });
  });

  ref.onDispose(() {
    subscription.cancel();
    syncDebounce?.cancel();
  });
}

Future<void> _syncTasksFromDiskIfChanged(Ref ref) async {
  try {
    final basePath = await FileStore.basePath;
    final diskContent = await File('$basePath/scheduler/tasks.json')
        .readAsString();
    final current = ref.read(schedulerProvider).value;
    // 与 store 的保存编码一致：内容相同说明是主引擎自身写入，无需刷新。
    final currentEncoded = current == null
        ? null
        : jsonEncode(current.map((t) => t.toJson()).toList(growable: false));
    if (diskContent == currentEncoded) {
      return;
    }
    debugPrint('[SchedulerBootstrap] tasks.json changed externally, reloading');
    await ref.read(schedulerProvider.notifier).reload();
  } catch (e) {
    debugPrint('[SchedulerBootstrap] Sync tasks failed: $e');
  }
}
