import 'dart:io';

class FileStore {
  static String? _basePath;

  static Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final appData = Platform.environment['APPDATA'] ?? '';
    if (appData.isEmpty) {
      throw StateError('APPDATA environment variable not set');
    }
    _basePath = '$appData/itools';
    return _basePath!;
  }

  Future<String> readJson(String relativePath) async {
    final file = File('${await basePath}/$relativePath');
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> writeJson(String relativePath, String content) async {
    final file = File('${await basePath}/$relativePath');
    await file.parent.create(recursive: true);
    // 原子写入：先写临时文件再 rename 替换，避免写一半崩溃导致文件损坏。
    // rename 会替换已存在的目标文件；写入方与监听方（目录 watch）均兼容。
    final tmpFile = File('${file.path}.tmp');
    try {
      await tmpFile.writeAsString(content, flush: true);
      await tmpFile.rename(file.path);
    } catch (_) {
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {
        // ignore cleanup errors
      }
      rethrow;
    }
  }

  Future<void> delete(String relativePath) async {
    final file = File('${await basePath}/$relativePath');
    if (await file.exists()) await file.delete();
  }

  Future<bool> exists(String relativePath) async {
    return File('${await basePath}/$relativePath').exists();
  }
}
