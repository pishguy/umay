import 'dart:io';

class FileUtils {
  /// فایل [tempPath] رو به صورت atomic جایگزین [targetPath] می‌کنه.
  static Future<void> atomicReplace(
      String tempPath,
      String targetPath,
      ) async {
    final tempFile = File(tempPath);
    final targetFile = File(targetPath);

    if (!await tempFile.exists()) return;
    if (await targetFile.exists()) await targetFile.delete();
    await tempFile.rename(targetPath);
  }

  /// فایل رو بدون exception حذف می‌کنه.
  static Future<void> safeDelete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// مطمئن میشه دایرکتوری وجود داره.
  static Future<void> ensureDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// اندازه فایل. اگه نبود 0 برمی‌گردونه.
  static Future<int> fileSize(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// فایل وجود داره و خالی نیست.
  static Future<bool> existsAndNotEmpty(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    return await file.length() > 0;
  }
}