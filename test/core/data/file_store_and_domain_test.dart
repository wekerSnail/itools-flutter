import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itools/core/data/file_store.dart';
import 'package:itools/features/folder_mapping/domain/folder_mapping.dart';
import 'package:itools/features/scheduler/domain/scheduled_task.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('itools_test_');
    FileStore.debugBasePath = tempDir.path;
  });

  tearDown(() {
    FileStore.debugBasePath = null;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileStore', () {
    test('write then read json', () async {
      final store = FileStore();
      await store.writeJson('a/b.json', '{"x":1}');
      expect(await store.readJson('a/b.json'), '{"x":1}');
      expect(await store.exists('a/b.json'), isTrue);
    });

    test('serializes concurrent writes to same path', () async {
      final store = FileStore();
      final futures = [
        for (var i = 0; i < 20; i++) store.writeJson('c.json', '"$i"'),
      ];
      await Future.wait(futures);
      final content = await store.readJson('c.json');
      // 最后一次写入获胜；内容必须是合法 JSON 字符串而非交错混杂。
      expect(content, matches(RegExp(r'^"\d+"$')));
    });

    test('delete removes file', () async {
      final store = FileStore();
      await store.writeJson('d.json', '{}');
      await store.delete('d.json');
      expect(await store.exists('d.json'), isFalse);
    });
  });

  group('FolderCollection.fromJson', () {
    test('skips corrupt items but keeps good ones', () {
      final collection = FolderCollection.fromJson({
        'id': 'c1',
        'name': 'n',
        'createdAt': '2020-01-01T00:00:00.000',
        'items': [
          {
            'id': 'i1',
            'name': 'good',
            'targetPath': 'C:\\ok',
            'createdAt': '2020-01-01T00:00:00.000',
          },
          {'id': 'bad'}, // missing fields
          {
            'id': 'i2',
            'name': 'good2',
            'targetPath': 'D:\\ok',
            'createdAt': '2020-01-01T00:00:00.000',
          },
        ],
      });
      expect(collection.items, hasLength(2));
      expect(collection.items.first.name, 'good');
      expect(collection.items.last.name, 'good2');
    });
  });

  group('TaskVariable.copyWith', () {
    test('can clear value', () {
      final v = TaskVariable(
        name: 'x',
        type: TaskVariableType.string,
        value: 'hello',
      );
      final cleared = v.copyWith(clearValue: true);
      expect(cleared.value, isNull);
      final kept = v.copyWith(name: 'y');
      expect(kept.value, 'hello');
    });
  });
}
