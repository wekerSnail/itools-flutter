import 'dart:io';

class FolderOpener {
  const FolderOpener();

  Future<void> open(String path) async {
    // Paths are user-controlled. Pass as argv without a shell so `&`, `|`
    // and similar characters in folder names are never re-parsed.
    if (Platform.isWindows) {
      await Process.start('explorer', [path]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.start('open', [path]);
      return;
    }

    await Process.start('xdg-open', [path]);
  }
}
