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
    await file.writeAsString(content, flush: true);
  }

  Future<void> delete(String relativePath) async {
    final file = File('${await basePath}/$relativePath');
    if (await file.exists()) await file.delete();
  }

  Future<bool> exists(String relativePath) async {
    return File('${await basePath}/$relativePath').exists();
  }
}
