import 'dart:io';

class FolderOpener {
  const FolderOpener();

  Future<void> open(String path) async {
    if (Platform.isWindows) {
      await Process.start('explorer', [path], runInShell: true);
      return;
    }

    if (Platform.isMacOS) {
      await Process.start('open', [path], runInShell: true);
      return;
    }

    await Process.start('xdg-open', [path], runInShell: true);
  }
}
