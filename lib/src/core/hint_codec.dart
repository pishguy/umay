import 'dart:typed_data';

class HintCodec {
  /// Encode: [keyLength:4] [keyBytes] [offset:8]
  static Uint8List encode(String key, int offset) {
    final keyBytes = Uint8List.fromList(key.codeUnits);
    final builder = BytesBuilder();

    builder.add(_int32(keyBytes.length));
    builder.add(keyBytes);
    builder.add(_int64(offset));

    return builder.toBytes();
  }

  /// Decode a single hint entry
  /// Returns (key, offset)
  static MapEntry<String, int> decode(Uint8List data) {
    int pos = 0;

    final keyLen = _readInt32(data, pos);
    pos += 4;

    final key = String.fromCharCodes(data.sublist(pos, pos + keyLen));
    pos += keyLen;

    final offset = _readInt64(data, pos);

    return MapEntry(key, offset);
  }

  static Uint8List _int32(int v) {
    final b = ByteData(4);
    b.setInt32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _int64(int v) {
    final b = ByteData(8);
    b.setInt64(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _readInt32(Uint8List data, int o) {
    return ByteData.sublistView(data, o, o + 4)
        .getInt32(0, Endian.big);
  }

  static int _readInt64(Uint8List data, int o) {
    return ByteData.sublistView(data, o, o + 8)
        .getInt64(0, Endian.big);
  }
}
