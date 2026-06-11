import 'dart:io';
import 'dart:typed_data';

/// A file wrapper that maintains two separate [RandomAccessFile] handles:
/// - one opened in write-only-append mode  (for [append])
/// - one opened in read mode               (for [readAt] / [length])
///
/// Using a single FileMode.append handle and then calling setPosition() for
/// reads is unreliable on some OS-es (writes always go to EOF regardless of
/// position). Keeping them separate avoids the problem entirely.
class StorageFile {
  final String path;

  RandomAccessFile? _writeRaf;
  RandomAccessFile? _readRaf;
  int _writePosition = 0;

  StorageFile(this.path);

  Future<void> open() async {
    final file = File(path);

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    _writeRaf = await file.open(mode: FileMode.writeOnlyAppend);
    _readRaf  = await file.open(mode: FileMode.read);
    _writePosition = await _writeRaf!.length();
  }

  Future<void> close() async {
    await _writeRaf?.close();
    await _readRaf?.close();
    _writeRaf = null;
    _readRaf  = null;
  }

  Future<int> length() async {
    final raf = _writeRaf;
    if (raf == null) throw StateError('StorageFile is not open');
    return raf.length();
  }

  /// Appends [bytes] to the end of the file.
  /// Returns the byte-offset at which the data starts.
  Future<int> append(Uint8List bytes) async {
    final wraf = _writeRaf;
    if (wraf == null) throw StateError('StorageFile is not open');

    final offset = _writePosition;
    await wraf.writeFrom(bytes);
    _writePosition += bytes.length;
    return offset;
  }

  /// Reads exactly [length] bytes starting at [offset].
  Future<Uint8List> readAt(int offset, int length) async {
    final rraf = _readRaf;
    if (rraf == null) throw StateError('StorageFile is not open');

    await rraf.setPosition(offset);
    final data = await rraf.read(length);

    if (data.length != length) {
      throw StateError(
        'Unexpected EOF: wanted $length bytes at offset $offset, '
            'got ${data.length}',
      );
    }

    return Uint8List.fromList(data);
  }
}