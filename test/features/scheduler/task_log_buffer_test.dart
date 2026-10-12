import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itools/core/data/file_store.dart';
import 'package:itools/features/scheduler/data/task_log_buffer.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('itools_logbuf_');
    FileStore.debugBasePath = tempDir.path;
  });

  tearDown(() async {
    FileStore.debugBasePath = null;
    // Windows 下防抖落盘可能仍在写入，文件句柄未释放，删除需重试。
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  TaskLogBuffer createBuffer({int maxEntries = 2000}) {
    return TaskLogBuffer(
      maxEntries: maxEntries,
      notifyThrottle: Duration.zero,
      // 防抖设为极长：测试里显式 await save()，避免用例结束后
      // 后台落盘与 tearDown 删目录竞态。
      saveDebounce: const Duration(hours: 1),
    );
  }

  RunnerLogEntry entry(String message, {Duration age = Duration.zero}) {
    return RunnerLogEntry(
      createdAt: DateTime.now().subtract(age),
      message: message,
    );
  }

  /// 等待合并通知 / 防抖落盘的 timer 触发。
  Future<void> settle() {
    return Future<void>.delayed(const Duration(milliseconds: 10));
  }

  test('logs are exposed newest-first', () async {
    final buffer = createBuffer()
      ..append(entry('first'))
      ..append(entry('second'));
    await settle();

    expect(buffer.logs.value, <String>['second', 'first']);
    buffer.dispose();
  });

  test('caps entries to maxEntries, dropping oldest', () async {
    final buffer = createBuffer(maxEntries: 3);
    for (var i = 1; i <= 5; i++) {
      buffer.append(entry('m$i'));
    }
    await settle();

    expect(buffer.logs.value, <String>['m5', 'm4', 'm3']);
    buffer.dispose();
  });

  test('drops entries older than retention', () async {
    final buffer = createBuffer()
      ..append(entry('old', age: const Duration(days: 10)))
      ..append(entry('new'));
    await settle();

    expect(buffer.logs.value, <String>['new']);
    buffer.dispose();
  });

  test('persists to disk and reloads', () async {
    final buffer = createBuffer()..append(entry('persisted'));
    await settle();
    await buffer.save();

    final reloaded = createBuffer();
    await reloaded.load();

    expect(reloaded.logs.value, <String>['persisted']);
    buffer.dispose();
    reloaded.dispose();
  });
}
