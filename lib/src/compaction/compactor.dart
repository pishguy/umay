import 'dart:io';

import '../core/box_index.dart';
import '../core/hint_codec.dart';
import '../core/index_snapshot.dart';
import '../core/record_codec.dart';
import '../core/storage_file.dart';

class Compactor {
  final String dbPath;
  final String idxPath;
  final String hintPath;

  Compactor(this.dbPath, this.idxPath, this.hintPath);

  /// Returns new index map after compaction.
  Future<Map<String, int>> compact(BoxIndex currentIndex) async {
    final snapshot = currentIndex.toMap();
    if (snapshot.isEmpty) return const {};

    final oldFile = StorageFile(dbPath);
    await oldFile.open();

    final tmpDbPath = '$dbPath.compact';
    final tmpHintPath = '$hintPath.tmp';

    final newFile = StorageFile(tmpDbPath);
    await newFile.open();

    final newIndex = <String, int>{};

    try {
      final liveEntries = snapshot.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final entry in liveEntries) {
        final key = entry.key;
        final offset = entry.value;

        final headerBytes =
        await oldFile.readAt(offset, RecordCodec.headerSize);
        final header = RecordCodec.decodeHeader(headerBytes);
        final recordBytes =
        await oldFile.readAt(offset, header.totalLength);

        // Validate CRC before copy
        RecordCodec.decodeWithCrc(recordBytes);

        final newOffset = await newFile.append(recordBytes);
        newIndex[key] = newOffset;
      }

      await oldFile.close();
      await newFile.close();

      // Write new index snapshot
      await IndexSnapshot.save(idxPath, newIndex);

      // Write new hint file
      final tmpHint = StorageFile(tmpHintPath);
      await tmpHint.open();
      for (final entry in newIndex.entries) {
        await tmpHint.append(HintCodec.encode(entry.key, entry.value));
      }
      await tmpHint.close();

      await _replaceFile(tmpDbPath, dbPath);
      await _replaceFile(tmpHintPath, hintPath);

      return newIndex;
    } catch (_) {
      try { await oldFile.close(); } catch (_) {}
      try { await newFile.close(); } catch (_) {}
      await _safeDelete(tmpDbPath);
      await _safeDelete(tmpHintPath);
      rethrow;
    }
  }

  Future<void> _replaceFile(String tempPath, String targetPath) async {
    final tempFile = File(tempPath);
    final targetFile = File(targetPath);

    if (!await tempFile.exists()) return;
    if (await targetFile.exists()) await targetFile.delete();
    await tempFile.rename(targetPath);
  }

  Future<void> _safeDelete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try { await file.delete(); } catch (_) {}
    }
  }
}