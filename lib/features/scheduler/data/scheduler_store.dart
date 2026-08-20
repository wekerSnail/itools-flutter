import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';
import '../domain/scheduled_task.dart';

class SchedulerStore {
  static const _path = 'scheduler/tasks.json';
  final _store = FileStore();

  Future<List<ScheduledTask>> loadTasks() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      // 整个文件损坏（非法 JSON）时返回空列表，避免一条坏数据拖垮整个模块。
      debugPrint('[SchedulerStore] tasks.json is corrupted, reset to empty: $e');
      return [];
    }

    final tasks = <ScheduledTask>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        tasks.add(ScheduledTask.fromJson(entry));
      } catch (e) {
        // 单条脏数据（如 startAt 非法）跳过，不影响其余任务加载。
        debugPrint('[SchedulerStore] Skip corrupted task entry: $e');
      }
    }
    return tasks;
  }

  Future<void> saveTasks(List<ScheduledTask> tasks) async {
    final encoded = jsonEncode(
      tasks.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
