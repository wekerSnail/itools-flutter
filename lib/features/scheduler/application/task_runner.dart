import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/task_log_buffer.dart';
import '../domain/scheduled_task.dart';
import 'cmd_escape.dart';

class TaskRunner {
  TaskRunner();

  static const Duration _defaultProcessTimeout = Duration(seconds: 600);

  /// 日志缓冲：环形淘汰 + 合并通知 + 防抖落盘。
  final TaskLogBuffer _logBuffer = TaskLogBuffer();

  /// 对外日志通知（倒序，下标 0 为最新）。
  ValueNotifier<List<String>> get logs => _logBuffer.logs;

  final Map<String, int> _lastOccurrenceByTaskId = <String, int>{};

  /// 执行中的任务 id：Timer.periodic 不会 await 回调结束，
  /// 同一任务跨过下一 occurrence 会并发重入，用此集合跳过。
  final Set<String> _inFlightTaskIds = <String>{};

  bool _logsLoaded = false;
  Timer? _timer;

  Future<void> start({
    required List<ScheduledTask> Function() tasksProvider,
  }) async {
    await _ensureLogsLoaded();

    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_logsLoaded) {
        return;
      }

      final now = DateTime.now();
      final tasks = tasksProvider();
      for (final task in tasks) {
        if (!_isDue(task, now)) {
          continue;
        }

        _lastOccurrenceByTaskId[task.id] = _occurrenceIndex(task, now);
        await _execute(task);
      }
    });
  }

  Future<void> runNow(ScheduledTask task) async {
    await _ensureLogsLoaded();
    _appendLog('[${DateTime.now()}] 手动触发任务 ${task.name}');
    await _execute(task);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _logBuffer.dispose();
  }

  bool _isDue(ScheduledTask task, DateTime now) {
    if (!task.enabled || now.isBefore(task.startAt)) {
      return false;
    }
    // 运行期防御：间隔 < 1 会让周期计算除零，直接跳过该任务。
    if (task.intervalValue < 1) {
      return false;
    }

    final currentOccurrence = _occurrenceIndex(task, now);
    final lastOccurrence = _lastOccurrenceByTaskId[task.id];
    return currentOccurrence >= 0 && lastOccurrence != currentOccurrence;
  }

  int _occurrenceIndex(ScheduledTask task, DateTime now) {
    if (now.isBefore(task.startAt)) {
      return -1;
    }

    switch (task.intervalUnit) {
      case ScheduleUnit.second:
        return _fixedUnitOccurrence(
          task,
          now,
          const Duration(seconds: 1).inMilliseconds,
        );
      case ScheduleUnit.minute:
        return _fixedUnitOccurrence(
          task,
          now,
          const Duration(minutes: 1).inMilliseconds,
        );
      case ScheduleUnit.hour:
        return _fixedUnitOccurrence(
          task,
          now,
          const Duration(hours: 1).inMilliseconds,
        );
      case ScheduleUnit.day:
        return _fixedUnitOccurrence(
          task,
          now,
          const Duration(days: 1).inMilliseconds,
        );
      case ScheduleUnit.week:
        return _fixedUnitOccurrence(
          task,
          now,
          const Duration(days: 7).inMilliseconds,
        );
      case ScheduleUnit.month:
        return _monthOccurrence(task, now);
    }
  }

  int _fixedUnitOccurrence(ScheduledTask task, DateTime now, int baseUnitMs) {
    final deltaMs =
        now.millisecondsSinceEpoch - task.startAt.millisecondsSinceEpoch;
    final cycleMs = task.intervalValue * baseUnitMs;
    return deltaMs ~/ cycleMs;
  }

  int _monthOccurrence(ScheduledTask task, DateTime now) {
    final totalMonths =
        (now.year - task.startAt.year) * 12 + (now.month - task.startAt.month);

    var index = totalMonths ~/ task.intervalValue;
    var scheduled = _addMonths(task.startAt, index * task.intervalValue);

    while (index > 0 && scheduled.isAfter(now)) {
      index -= 1;
      scheduled = _addMonths(task.startAt, index * task.intervalValue);
    }

    while (true) {
      final next = _addMonths(task.startAt, (index + 1) * task.intervalValue);
      if (next.isAfter(now)) {
        break;
      }
      index += 1;
      if (index > 100000) {
        break;
      }
    }

    return index;
  }

  DateTime _addMonths(DateTime date, int monthsToAdd) {
    final total = date.month - 1 + monthsToAdd;
    final year = date.year + (total ~/ 12);
    final month = (total % 12) + 1;
    final day = date.day.clamp(1, _daysInMonth(year, month));
    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  int _daysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  String _applyVariables(String command, Map<String, dynamic> variables) {
    return applyCmdVariables(command, variables);
  }

  Future<void> _execute(ScheduledTask task) async {
    if (!_inFlightTaskIds.add(task.id)) {
      _appendLog('[${DateTime.now()}] 任务 ${task.name} 仍在执行中，跳过本次触发');
      return;
    }
    try {
      _appendLog('[${DateTime.now()}] 开始执行任务 ${task.name}');
      switch (task.type) {
        case ScheduledTaskType.terminalCommand:
          await _executeTerminalCommand(task);
        case ScheduledTaskType.jsScript:
          await _executeJsScript(task);
      }
    } finally {
      _inFlightTaskIds.remove(task.id);
    }
  }

  Future<void> _executeTerminalCommand(ScheduledTask task) async {
    final cmd = _applyVariables(task.command, task.runtimeVariables);
    // 写入临时 .cmd 再执行：批处理文件中 `%%` 才是真正的 `%` 转义，
    // 且避免 `cmd /c` + `runInShell: true` 双重 shell 对变量二次解析。
    final tempDir = await Directory.systemTemp.createTemp('toolbox_cmd_');
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}task_${task.id}.cmd',
    );
    await scriptFile.writeAsString(cmd, flush: true);

    try {
      final process = await Process.start('cmd', ['/c', scriptFile.path]);

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog('[${task.name}] $line'));
      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog('[${task.name}][ERR] $line'));

      try {
        final code = await _waitForExit(process, task);
        _appendLog('[${DateTime.now()}] 任务 ${task.name} 结束，退出码: $code');
      } finally {
        await stdoutSub.cancel();
        await stderrSub.cancel();
      }
    } catch (e) {
      _appendLog('[${DateTime.now()}] 任务 ${task.name} 执行失败: $e');
    } finally {
      try {
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
        await tempDir.delete();
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }

  static bool? _nodeAvailable;

  Future<bool> _detectNode() async {
    try {
      final whereNode = await Process.run('where', ['node']);
      return whereNode.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _executeJsScript(ScheduledTask task) async {
    if (task.script == null || task.script!.trim().isEmpty) {
      _appendLog('[${DateTime.now()}] 任务 ${task.name} 执行失败: JS 脚本为空');
      return;
    }

    _nodeAvailable ??= await _detectNode();
    if (_nodeAvailable != true) {
      _appendLog(
        '[${DateTime.now()}] 任务 ${task.name} 执行失败: 未检测到 Node.js，请先安装并配置 PATH',
      );
      return;
    }

    final runtimeVariables = task.runtimeVariables;
    final tempDir = await Directory.systemTemp.createTemp('toolbox_js_');
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}task_${task.id}.js',
    );

    final wrappedScript =
        '''
const vars = ${jsonEncode(runtimeVariables)};
${task.script}
''';

    await scriptFile.writeAsString(wrappedScript, flush: true);

    try {
      final process = await Process.start('node', [scriptFile.path]);

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog('[${task.name}][JS] $line'));
      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog('[${task.name}][JS][ERR] $line'));

      try {
        final code = await _waitForExit(process, task, jsLabel: true);
        _appendLog('[${DateTime.now()}] JS 任务 ${task.name} 结束，退出码: $code');
      } finally {
        await stdoutSub.cancel();
        await stderrSub.cancel();
      }
    } catch (e) {
      _appendLog('[${DateTime.now()}] JS 任务 ${task.name} 执行失败: $e');
    } finally {
      try {
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
        await tempDir.delete();
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }

  /// 等待进程退出，超时后强制结束整个进程树。
  ///
  /// 命令通过 cmd 派生子进程，直接 kill 只能终止
  /// 直接子进程，必须用 taskkill /T 整树终止，否则挂死命令会
  /// 在长期后台运行中不断泄漏进程。
  Future<int> _waitForExit(
    Process process,
    ScheduledTask task, {
    bool jsLabel = false,
  }) {
    final timeout = task.timeoutSeconds == null
        ? _defaultProcessTimeout
        : Duration(seconds: task.timeoutSeconds!);
    final label = jsLabel ? 'JS 任务' : '任务';
    return process.exitCode.timeout(
      timeout,
      onTimeout: () async {
        await _killProcessTree(process.pid);
        _appendLog(
          '[${DateTime.now()}] $label ${task.name} '
          '超过 ${timeout.inSeconds}s 未结束，已强制终止进程树',
        );
        return -1;
      },
    );
  }

  Future<void> _killProcessTree(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/T', '/F', '/PID', '$pid']);
      } else {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
    } catch (_) {
      // 进程可能已自行退出，忽略终止失败。
    }
  }

  void _appendLog(String line) {
    _logBuffer.append(
      RunnerLogEntry(createdAt: DateTime.now(), message: line.trimRight()),
    );
  }

  Future<void> _ensureLogsLoaded() async {
    if (_logsLoaded) {
      return;
    }
    await _loadLogsFromDisk();
    _logsLoaded = true;
  }

  /// 从磁盘重新加载日志并刷新通知。
  ///
  /// 子窗口场景：日志由主引擎写入，本引擎的内存副本不会自动更新，
  /// 日志页监听文件变化后调用此方法刷新展示。
  Future<void> reloadLogs() async {
    await _loadLogsFromDisk();
    _logsLoaded = true;
  }

  Future<void> _loadLogsFromDisk() async {
    await _logBuffer.load();
  }
}
