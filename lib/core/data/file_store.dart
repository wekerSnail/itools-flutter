import 'dart:async';
import 'dart:io';

class FileStore {
  static String? _basePath;

  /// 按 relativePath 串行化写入，避免并发共用同一 `.tmp` 交错写出混杂内容。
  static final Map<String, Future<void>> _writeChains = <String, Future<void>>{};

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

  Future<void> writeJson(String relativePath, String content) {
    final previous = _writeChains[relativePath] ?? Future<void>.value();
    final current = previous.then(
      (_) => _writeJsonUnlocked(relativePath, content),
    );
    // 锁链吞掉失败，保证后续写入仍能执行；调用方仍会收到 current 的错误。
    _writeChains[relativePath] = current.then<void>(
      (_) {},
      onError: (_) {},
    );
    return current;
  }

  Future<void> _writeJsonUnlocked(String relativePath, String content) async {
    final file = File('${await basePath}/$relativePath');
    await file.parent.create(recursive: true);
    // 原子写入：先写临时文件再 rename 替换，避免写一半崩溃导致文件损坏。
    // rename 会替换已存在的目标文件；写入方与监听方（目录 watch）均兼容。
    // 同路径写入已由 _writeChains 串行化，不会交错写同一 tmp。
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
