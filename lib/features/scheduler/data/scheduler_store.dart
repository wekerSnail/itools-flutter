import 'dart:convert';

import '../../../core/data/file_store.dart';
import '../domain/scheduled_task.dart';

class SchedulerStore {
  static const _path = 'scheduler/tasks.json';
  final _store = FileStore();

  Future<List<ScheduledTask>> loadTasks() async {
    final raw = await _store.readJson(_path);
    if (raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ScheduledTask.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveTasks(List<ScheduledTask> tasks) async {
    final encoded = jsonEncode(
      tasks.map((e) => e.toJson()).toList(growable: false),
    );
    await _store.writeJson(_path, encoded);
  }
}
