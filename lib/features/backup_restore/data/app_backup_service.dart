import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../../core/data/file_store.dart';

class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.itemCount,
    required this.keys,
  });

  final DateTime exportedAt;
  final int itemCount;
  final List<String> keys;
}

class AppBackupService {
  static const int _schemaVersion = 2;
  static const List<String> managedFiles = <String>[
    'scheduler/tasks.json',
    'scheduler/logs.json',
    'folder_mapping/collections.json',
  ];

  final _store = FileStore();

  Future<BackupSummary> getCurrentSummary() async {
    final existingFiles = <String>[];
    for (final path in managedFiles) {
      if (await _store.exists(path)) {
        existingFiles.add(path);
      }
    }
    return BackupSummary(
      exportedAt: DateTime.now(),
      itemCount: existingFiles.length,
      keys: existingFiles,
    );
  }

  Future<String?> exportBackup() async {
    final data = <String, String>{};
    for (final path in managedFiles) {
      final content = await _store.readJson(path);
      if (content.isNotEmpty) {
        data[path] = content;
      }
    }

    final location = await getSaveLocation(
      suggestedName: _buildSuggestedFileName(),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON 文件', extensions: <String>['json']),
      ],
    );
    if (location == null) return null;

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'app': 'itools-flutter',
      'exportedAt': DateTime.now().toIso8601String(),
      'files': data,
    };

    final file = File(location.path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file.path;
  }

  Future<BackupSummary?> importBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON 文件', extensions: <String>['json']),
      ],
    );
    if (file == null) return null;

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件格式不正确');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _schemaVersion) {
      throw const FormatException('备份文件版本不受支持');
    }

    final files = decoded['files'];
    if (files is! Map<String, dynamic>) {
      throw const FormatException('备份文件缺少数据内容');
    }

    for (final entry in files.entries) {
      await _store.writeJson(entry.key, entry.value.toString());
    }

    return BackupSummary(
      exportedAt:
          DateTime.tryParse(decoded['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemCount: files.length,
      keys: files.keys.toList(growable: false),
    );
  }

  String _buildSuggestedFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'itools_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
  }
}
