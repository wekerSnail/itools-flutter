import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/scheduled_task.dart';

class SchedulerStore {
  static const _tasksKey = 'scheduler.tasks.v1';

  Future<List<ScheduledTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ScheduledTask.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveTasks(List<ScheduledTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      tasks.map((e) => e.toJson()).toList(growable: false),
    );
    await prefs.setString(_tasksKey, encoded);
  }
}
