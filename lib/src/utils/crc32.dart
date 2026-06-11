import 'dart:typed_data';

class CRC32 {
  static const int _poly = 0xEDB88320;
  static final List<int> _table = _createTable();

  static List<int> _createTable() {
    final table = List<int>.filled(256, 0);

    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int j = 0; j < 8; j++) {
        if ((c & 1) != 0) {
          c = _poly ^ (c >> 1);
        } else {
          c = c >> 1;
        }
      }
      table[i] = c;
    }

    return table;
  }

  static int compute(Uint8List data) {
    int crc = 0xffffffff;

    for (final b in data) {
      crc = _table[(crc ^ b) & 0xff] ^ (crc >> 8);
    }

    return crc ^ 0xffffffff;
  }
}
