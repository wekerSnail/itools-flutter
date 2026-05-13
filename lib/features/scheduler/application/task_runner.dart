import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';
import '../domain/scheduled_task.dart';

class TaskRunner {
  TaskRunner();

  static const String _logsPath = 'scheduler/logs.json';
  static const Duration _logRetentionDuration = Duration(days: 5);
  final _store = FileStore();

  final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>(
    <String>[],
  );
  final Map<String, int> _lastOccurrenceByTaskId = <String, int>{};
  final List<_RunnerLogEntry> _logEntries = <_RunnerLogEntry>[];

  bool _logsLoaded = false;
  Timer? _saveLogsDebounceTimer;
  Timer? _timer;

  void start({required List<ScheduledTask> Function() tasksProvider}) {
    _ensureLogsLoaded();

    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
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
    _saveLogsDebounceTimer?.cancel();
    logs.dispose();
  }

  bool _isDue(ScheduledTask task, DateTime now) {
    if (!task.enabled || now.isBefore(task.startAt)) {
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
    var result = command;
    for (final entry in variables.entries) {
      final value = entry.value;
      final textValue = value is String ? value : jsonEncode(value);
      result = result.replaceAll('{{${entry.key}}}', textValue);
    }
    return result;
  }

  Future<void> _execute(ScheduledTask task) async {
    _appendLog('[${DateTime.now()}] 开始执行任务 ${task.name}');
    switch (task.type) {
      case ScheduledTaskType.terminalCommand:
        await _executeTerminalCommand(task);
      case ScheduledTaskType.jsScript:
        await _executeJsScript(task);
    }
  }

  Future<void> _executeTerminalCommand(ScheduledTask task) async {
    final cmd = _applyVariables(task.command, task.runtimeVariables);
    try {
      final process = await Process.start('cmd', ['/c', cmd], runInShell: true);

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen((line) => _appendLog('[${task.name}] $line'));
      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen((line) => _appendLog('[${task.name}][ERR] $line'));

      try {
        final code = await process.exitCode;
        _appendLog('[${DateTime.now()}] 任务 ${task.name} 结束，退出码: $code');
      } finally {
        await stdoutSub.cancel();
        await stderrSub.cancel();
      }
    } catch (e) {
      _appendLog('[${DateTime.now()}] 任务 ${task.name} 执行失败: $e');
    }
  }

  Future<void> _executeJsScript(ScheduledTask task) async {
    if (task.script == null || task.script!.trim().isEmpty) {
      _appendLog('[${DateTime.now()}] 任务 ${task.name} 执行失败: JS 脚本为空');
      return;
    }

    final whereNode = await Process.run('where', ['node'], runInShell: true);
    if (whereNode.exitCode != 0) {
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
      final process = await Process.start('node', [
        scriptFile.path,
      ], runInShell: true);

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen((line) => _appendLog('[${task.name}][JS] $line'));
      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen((line) => _appendLog('[${task.name}][JS][ERR] $line'));

      try {
        final code = await process.exitCode;
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

  void _appendLog(String line) {
    final now = DateTime.now();
    _logEntries.insert(
      0,
      _RunnerLogEntry(createdAt: now, message: line.trimRight()),
    );

    _pruneExpiredLogs(now: now);
    if (_logEntries.length > 2000) {
      _logEntries.removeRange(2000, _logEntries.length);
    }

    logs.value = _logEntries.map((e) => e.message).toList(growable: false);
    _debouncedSaveLogs();
  }

  Future<void> _ensureLogsLoaded() async {
    if (_logsLoaded) {
      return;
    }

    final raw = await _store.readJson(_logsPath);
    if (raw.isEmpty) {
      _logsLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _logEntries
        ..clear()
        ..addAll(
          decoded.map(
            (e) => _RunnerLogEntry.fromJson(e as Map<String, dynamic>),
          ),
        );

      _pruneExpiredLogs(now: DateTime.now());
      logs.value = _logEntries.map((e) => e.message).toList(growable: false);
    } catch (_) {
      _logEntries.clear();
      logs.value = <String>[];
    } finally {
      _logsLoaded = true;
      _debouncedSaveLogs();
    }
  }

  void _pruneExpiredLogs({required DateTime now}) {
    final cutoff = now.subtract(_logRetentionDuration);
    _logEntries.removeWhere((e) => e.createdAt.isBefore(cutoff));
  }

  void _debouncedSaveLogs() {
    _saveLogsDebounceTimer?.cancel();
    _saveLogsDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _saveLogs();
    });
  }

  Future<void> _saveLogs() async {
    final payload = jsonEncode(
      _logEntries.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_logsPath, payload);
  }
}

class _RunnerLogEntry {
  _RunnerLogEntry({required this.createdAt, required this.message});

  final DateTime createdAt;
  final String message;

  factory _RunnerLogEntry.fromJson(Map<String, dynamic> json) {
    return _RunnerLogEntry(
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'message': message,
    };
  }
}
