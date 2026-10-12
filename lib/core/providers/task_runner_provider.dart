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

/// 调度器引导：只负责主引擎的任务监听、文件同步与轮询兜底。
///
/// 生命周期与 provider 绑定，所有可变状态收敛为实例字段，
/// 避免模块级全局 Timer 在多 container 场景下互相覆盖或泄漏，
/// 也避免 `await` 之后再注册 `ref.onDispose`。
class SchedulerBootstrap {
  SchedulerBootstrap(this._ref);

  final Ref _ref;
  StreamSubscription<FileSystemEvent>? _watchSub;
  Timer? _pollTimer;
  Timer? _syncDebounce;
  bool _disposed = false;

  void start() {
    // 任务列表就绪后启动 runner，保证调度器使用最新的任务定义。
    _ref.listen<AsyncValue<List<ScheduledTask>>>(schedulerProvider, (_, next) {
      next.whenData((tasks) async {
        if (_disposed) return;
        debugPrint(
          '[SchedulerBootstrap] Loaded ${tasks.length} tasks, starting runner',
        );
        await _ref.read(taskRunnerProvider.notifier).start(
          tasksProvider: () =>
              _ref.read(schedulerProvider).value ?? <ScheduledTask>[],
        );
      });
    });

    // 监听 tasks.json 变化（子窗口编辑 / 备份导入 / 外部修改），
    // 保证主引擎调度器始终使用最新任务定义，不会执行已禁用的任务。
    unawaited(_watchTasksFileForChanges());

    // 触发一次初始 reload。Riverpod 禁止在 provider 初始化期间同步修改其他
    // provider 的状态，这里调度到下一个事件循环再触发。
    unawaited(_reloadTasks());
  }

  void dispose() {
    _disposed = true;
    _watchSub?.cancel();
    _watchSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _syncDebounce?.cancel();
    _syncDebounce = null;
  }

  Future<void> _reloadTasks() async {
    // 先让出当前同步调用栈：async 函数体在首个 await 前依然同步执行，
    // 直接 read/reload 仍处于 provider 初始化期，会触发 Riverpod 断言。
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return;
    try {
      await _ref.read(schedulerProvider.notifier).reload();
    } catch (e) {
      debugPrint('[SchedulerBootstrap] Initial reload failed: $e');
    }
  }

  Future<void> _watchTasksFileForChanges() async {
    final basePath = await FileStore.basePath;
    if (_disposed) return;
    final schedulerDir = Directory('$basePath/scheduler');
    // 目录可能尚未创建；不创建就 watch 会失败，且此后外部修改永久失步。
    try {
      await schedulerDir.create(recursive: true);
    } catch (e) {
      debugPrint('[SchedulerBootstrap] Create scheduler dir failed: $e');
    }

    Stream<FileSystemEvent>? events;
    try {
      // 监听目录而非单个文件：原子写入（临时文件 rename）只产生目录事件，
      // 监听文件路径本身会漏掉替换。
      events = schedulerDir.watch();
    } catch (e) {
      debugPrint('[SchedulerBootstrap] Watch tasks.json failed: $e');
      _startTasksPollFallback();
      return;
    }

    _watchSub = events.listen(
      (event) {
        final path = event.path.replaceAll('\\', '/');
        if (!path.endsWith('scheduler/tasks.json')) {
          return;
        }
        _syncDebounce?.cancel();
        _syncDebounce = Timer(const Duration(milliseconds: 500), () {
          unawaited(_syncTasksFromDiskIfChanged());
        });
      },
      onError: (Object e) {
        // watch 流上的异步错误同样会失步，转入轮询兜底。
        debugPrint('[SchedulerBootstrap] Watch stream error: $e');
        _startTasksPollFallback();
      },
    );
  }

  void _startTasksPollFallback() {
    if (_disposed || _pollTimer != null) {
      return;
    }
    // 轮询兜底：watch 失败时不再静默放弃，保证外部修改仍能同步到内存。
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_syncTasksFromDiskIfChanged());
    });
  }

  Future<void> _syncTasksFromDiskIfChanged() async {
    if (_disposed) return;
    try {
      final basePath = await FileStore.basePath;
      final diskContent = await File('$basePath/scheduler/tasks.json')
          .readAsString();
      final current = _ref.read(schedulerProvider).value;
      // 与 store 的保存编码一致：内容相同说明是主引擎自身写入，无需刷新。
      final currentEncoded = current == null
          ? null
          : jsonEncode(current.map((t) => t.toJson()).toList(growable: false));
      if (diskContent == currentEncoded) {
        return;
      }
      debugPrint(
        '[SchedulerBootstrap] tasks.json changed externally, reloading',
      );
      await _ref.read(schedulerProvider.notifier).reload();
    } catch (e) {
      debugPrint('[SchedulerBootstrap] Sync tasks failed: $e');
    }
  }
}

/// Ensures tasks are loaded and the automatic scheduler is running.
/// Watch this provider once at app startup to bootstrap the scheduler.
final schedulerBootstrapProvider = Provider<SchedulerBootstrap>((ref) {
  final bootstrap = SchedulerBootstrap(ref);
  // 先同步注册清理，早于任何 await，避免 dispose 后使用 ref。
  ref.onDispose(bootstrap.dispose);
  bootstrap.start();
  return bootstrap;
});
