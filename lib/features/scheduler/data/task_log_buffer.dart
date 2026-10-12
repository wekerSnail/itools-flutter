import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';

/// 单条运行日志。
class RunnerLogEntry {
  RunnerLogEntry({required this.createdAt, required this.message});

  final DateTime createdAt;
  final String message;

  factory RunnerLogEntry.fromJson(Map<String, dynamic> json) {
    return RunnerLogEntry(
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

/// 运行日志内存缓冲。
///
/// - 时间正序存放在 [ListQueue]，超限/过期只从队首淘汰（O(淘汰数)），
///   替代原先「头插 + 全量 removeWhere」的 O(n) 写法。
/// - 追加只置脏标记，按 [notifyThrottle] 合并成一次 [ValueNotifier] 刷新，
///   避免每行日志都重建整份列表并触发 UI 重建。
/// - 落盘按 [saveDebounce] 防抖，且仅在脏标记存在时序列化。
class TaskLogBuffer {
  TaskLogBuffer({
    FileStore? store,
    this.relativePath = 'scheduler/logs.json',
    this.maxEntries = 2000,
    this.retention = const Duration(days: 5),
    this.notifyThrottle = const Duration(milliseconds: 120),
    this.saveDebounce = const Duration(milliseconds: 300),
  }) : _store = store ?? FileStore();

  final FileStore _store;
  final String relativePath;
  final int maxEntries;
  final Duration retention;
  final Duration notifyThrottle;
  final Duration saveDebounce;

  final ListQueue<RunnerLogEntry> _entries = ListQueue<RunnerLogEntry>();

  /// 对外通知：倒序（下标 0 为最新），与日志页 `reverse: true` 对应。
  final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>(
    const <String>[],
  );

  Timer? _notifyTimer;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _disposed = false;

  bool get isEmpty => _entries.isEmpty;

  void append(RunnerLogEntry entry) {
    _entries.addLast(entry);
    _trim(DateTime.now());
    _dirty = true;
    _scheduleNotify();
    _scheduleSave();
  }

  /// 从磁盘重新加载并刷新通知。
  ///
  /// 子窗口场景：日志由主引擎写入，本引擎的内存副本不会自动更新，
  /// 日志页监听文件变化后调用此方法刷新展示。
  Future<void> load() async {
    final raw = await _store.readJson(relativePath);
    _entries.clear();
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final e in decoded) {
          _entries.addLast(RunnerLogEntry.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        _entries.clear();
      }
    }
    _trim(DateTime.now());
    _dirty = true;
    _flush();
  }

  void _trim(DateTime now) {
    final cutoff = now.subtract(retention);
    while (_entries.isNotEmpty && _entries.first.createdAt.isBefore(cutoff)) {
      _entries.removeFirst();
    }
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  void _scheduleNotify() {
    if (_disposed) return;
    _notifyTimer ??= Timer(notifyThrottle, _flush);
  }

  void _flush() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    if (!_dirty || _disposed) return;
    _dirty = false;
    logs.value = _entries
        .toList(growable: false)
        .reversed
        .map((RunnerLogEntry e) => e.message)
        .toList(growable: false);
  }

  void _scheduleSave() {
    if (_disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounce, () => unawaited(save()));
  }

  Future<void> save() async {
    final payload = jsonEncode(
      _entries.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(relativePath, payload);
  }

  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    logs.dispose();
  }
}