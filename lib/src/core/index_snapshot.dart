// index_snapshot.dart
import 'dart:io';
import 'dart:typed_data';

/// Optional: if you have a logger, you can import and use it.
/// import '../utils/logger.dart';

/// Persistent snapshot of the in-memory index (key -> offset).
///
/// Binary format:
///   [0..3]   4 bytes  magic = 'DBIX' (0x44, 0x42, 0x49, 0x58)
///   [4]      1 byte   version = 1
///   [5..8]   4 bytes  total length of the payload (excluding magic+version+length), big endian
///   [9..12]  4 bytes  entry count (N), big endian
///   then repeated N times:
///       4 bytes   key length (K), big endian
///       8 bytes   record offset (int64), big endian
///       K bytes   key (UTF-8 codeUnits)
///
/// The file is written atomically by using a temporary file and rename.
class IndexSnapshot {
  static const int version = 1;

  // 4-byte "magic" header: 'D' 'B' 'I' 'X'
  static const int _magicD = 0x44;
  static const int _magicB = 0x42;
  static const int _magicI = 0x49;
  static const int _magicX = 0x58;

  /// Save [index] to [path] atomically.
  ///
  /// Writes to `[path].tmp` first, then renames to [path] to avoid
  /// leaving a partially written file on crash.
  static Future<void> save(String path, Map<String, int> index) async {
    final file = File(path);
    final tmpPath = '$path.tmp';
    final tmpFile = File(tmpPath);

    final builder = BytesBuilder();

    // Magic
    builder.add([_magicD, _magicB, _magicI, _magicX]);

    // Version
    builder.add([version]);

    // Placeholder for payload length (4 bytes, will fill later).
    final payloadLengthPlaceholder = ByteData(4);
    payloadLengthPlaceholder.setUint32(0, 0, Endian.big);
    builder.add(payloadLengthPlaceholder.buffer.asUint8List());

    // Entry count
    final countData = ByteData(4);
    countData.setUint32(0, index.length, Endian.big);
    builder.add(countData.buffer.asUint8List());

    // Entries
    index.forEach((key, offset) {
      final keyBytes = Uint8List.fromList(key.codeUnits);

      final keyLen = ByteData(4);
      keyLen.setUint32(0, keyBytes.length, Endian.big);
      builder.add(keyLen.buffer.asUint8List());

      final off = ByteData(8);
      off.setInt64(0, offset, Endian.big);
      builder.add(off.buffer.asUint8List());

      builder.add(keyBytes);
    });

    final fullBytes = builder.toBytes();

    // Fill payload length = total bytes - (magic(4) + version(1) + length field(4))
    final payloadLength = fullBytes.length - 9;
    final payloadLengthBytes = ByteData(4);
    payloadLengthBytes.setUint32(0, payloadLength, Endian.big);

    // Overwrite the placeholder in the buffer.
    fullBytes[5] = payloadLengthBytes.buffer.asUint8List()[0];
    fullBytes[6] = payloadLengthBytes.buffer.asUint8List()[1];
    fullBytes[7] = payloadLengthBytes.buffer.asUint8List()[2];
    fullBytes[8] = payloadLengthBytes.buffer.asUint8List()[3];

    // Write atomically via tmp + rename.
    final raf = await tmpFile.open(mode: FileMode.write);
    try {
      await raf.writeFrom(fullBytes);
      await raf.flush(); // best-effort flush to disk
    } finally {
      await raf.close();
    }

    // Atomically replace.
    // On most OSes, rename is atomic.
    await tmpFile.rename(file.path);
  }

  /// Load index snapshot from [path].
  ///
  /// Returns `null` if no snapshot exists, the file is empty, or invalid/corrupted.
  static Future<Map<String, int>?> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    int offset = 0;

    // Check at least magic + version + payloadLength
    if (bytes.length < 9) {
      return null;
    }

    // Magic
    if (bytes[offset] != _magicD ||
        bytes[offset + 1] != _magicB ||
        bytes[offset + 2] != _magicI ||
        bytes[offset + 3] != _magicX) {
      return null;
    }
    offset += 4;

    // Version
    final ver = bytes[offset];
    offset += 1;

    if (ver != version) {
      return null;
    }

    // Payload length
    final payloadLenView = ByteData.sublistView(bytes, offset, offset + 4);
    final payloadLength = payloadLenView.getUint32(0, Endian.big);
    offset += 4;

    // Sanity: remaining bytes should be exactly payloadLength
    final remaining = bytes.length - offset;
    if (remaining != payloadLength) {
      // Corrupted or truncated.
      return null;
    }

    // Need at least 4 bytes for count
    if (remaining < 4) {
      return null;
    }

    final countView = ByteData.sublistView(bytes, offset, offset + 4);
    final count = countView.getUint32(0, Endian.big);
    offset += 4;

    final map = <String, int>{};

    for (int i = 0; i < count; i++) {
      // Each entry: 4 bytes keyLength, 8 bytes offset, then key bytes.

      if (bytes.length < offset + 4) {
        return null; // truncated
      }
      final keyLenView =
      ByteData.sublistView(bytes, offset, offset + 4);
      final keyLength = keyLenView.getUint32(0, Endian.big);
      offset += 4;

      if (bytes.length < offset + 8) {
        return null; // truncated
      }
      final offView =
      ByteData.sublistView(bytes, offset, offset + 8);
      final recordOffset = offView.getInt64(0, Endian.big);
      offset += 8;

      if (keyLength == 0) {
        // allow empty keys if needed; else treat as corruption
        // return null;
      }

      if (bytes.length < offset + keyLength) {
        return null; // truncated
      }
      final keyBytes = bytes.sublist(offset, offset + keyLength);
      offset += keyLength;

      final key = String.fromCharCodes(keyBytes);
      map[key] = recordOffset;
    }

    return map;
  }
}
