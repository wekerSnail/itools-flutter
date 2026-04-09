import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const int _schemaVersion = 1;
  static const List<String> managedKeys = <String>[
    'folder.mapping.v2',
    'folder.mapping.v1',
    'scheduler.tasks.v1',
    'scheduler.logs.v1',
  ];

  Future<BackupSummary> getCurrentSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final existingKeys = managedKeys
        .where((key) => prefs.get(key) != null)
        .toList(growable: false);
    return BackupSummary(
      exportedAt: DateTime.now(),
      itemCount: existingKeys.length,
      keys: existingKeys,
    );
  }

  Future<String?> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    for (final key in managedKeys) {
      final value = prefs.get(key);
      if (value != null) {
        data[key] = _encodeValue(value);
      }
    }

    final location = await getSaveLocation(
      suggestedName: _buildSuggestedFileName(),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON 文件', extensions: <String>['json']),
      ],
    );
    if (location == null) {
      return null;
    }

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'app': 'itools-flutter',
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };

    final file = File(location.path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file.path;
  }

  Future<BackupSummary?> inspectBackupFile() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON 文件', extensions: <String>['json']),
      ],
    );
    if (file == null) {
      return null;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件格式不正确');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _schemaVersion) {
      throw const FormatException('备份文件版本不受支持');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('备份文件缺少数据内容');
    }

    return BackupSummary(
      exportedAt:
          DateTime.tryParse(decoded['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemCount: data.length,
      keys: data.keys.toList(growable: false),
    );
  }

  Future<BackupSummary?> importBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON 文件', extensions: <String>['json']),
      ],
    );
    if (file == null) {
      return null;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件格式不正确');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _schemaVersion) {
      throw const FormatException('备份文件版本不受支持');
    }

    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('备份文件缺少数据内容');
    }

    final prefs = await SharedPreferences.getInstance();
    for (final key in managedKeys) {
      await prefs.remove(key);
    }

    for (final entry in rawData.entries) {
      await _restoreValue(prefs, entry.key, entry.value);
    }

    return BackupSummary(
      exportedAt:
          DateTime.tryParse(decoded['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemCount: rawData.length,
      keys: rawData.keys.toList(growable: false),
    );
  }

  String _buildSuggestedFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'itools_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
  }

  Map<String, dynamic> _encodeValue(Object value) {
    if (value is String) {
      return <String, dynamic>{'type': 'string', 'value': value};
    }
    if (value is int) {
      return <String, dynamic>{'type': 'int', 'value': value};
    }
    if (value is double) {
      return <String, dynamic>{'type': 'double', 'value': value};
    }
    if (value is bool) {
      return <String, dynamic>{'type': 'bool', 'value': value};
    }
    if (value is List<String>) {
      return <String, dynamic>{'type': 'stringList', 'value': value};
    }
    throw UnsupportedError('不支持导出该类型: ${value.runtimeType}');
  }

  Future<void> _restoreValue(
    SharedPreferences prefs,
    String key,
    dynamic encoded,
  ) async {
    if (encoded is! Map<String, dynamic>) {
      throw const FormatException('备份项格式不正确');
    }

    final type = encoded['type']?.toString();
    final value = encoded['value'];

    switch (type) {
      case 'string':
        await prefs.setString(key, value?.toString() ?? '');
        break;
      case 'int':
        await prefs.setInt(
          key,
          value is int ? value : int.parse(value.toString()),
        );
        break;
      case 'double':
        await prefs.setDouble(
          key,
          value is double ? value : double.parse(value.toString()),
        );
        break;
      case 'bool':
        await prefs.setBool(
          key,
          value == true || value.toString().toLowerCase() == 'true',
        );
        break;
      case 'stringList':
        await prefs.setStringList(
          key,
          (value as List<dynamic>).map((e) => e.toString()).toList(),
        );
        break;
      default:
        throw FormatException('不支持的备份项类型: $type');
    }
  }
}
