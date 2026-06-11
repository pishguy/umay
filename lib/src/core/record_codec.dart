
import 'dart:typed_data';

class RecordHeader {
  final bool deleted;
  final int keyLength;
  final int valueLength;

  const RecordHeader({
    required this.deleted,
    required this.keyLength,
    required this.valueLength,
  });

  int get baseLength => RecordCodec.headerSize + keyLength + valueLength;
  int get totalLength => baseLength;
}

class RecordCodec {
  /// [deleted:1][keyLen:4][valueLen:4]
  static const int headerSize = 9;

  static const int crcSize = 0;

  static Uint8List encode({
    required bool deleted,
    required Uint8List key,
    required Uint8List value,
  }) {
    final builder = BytesBuilder();

    builder.addByte(deleted ? 1 : 0);
    builder.add(_uint32(key.length));
    builder.add(_uint32(value.length));
    builder.add(key);
    builder.add(value);

    return builder.toBytes();
  }

  static RecordHeader decodeHeader(Uint8List headerBytes) {
    if (headerBytes.length < headerSize) {
      throw StateError('Header must be at least $headerSize bytes');
    }

    int offset = 0;

    final deletedFlag = headerBytes[offset] == 1;
    offset += 1;

    final keyLength = _readUint32(headerBytes, offset);
    offset += 4;

    final valueLength = _readUint32(headerBytes, offset);

    return RecordHeader(
      deleted: deletedFlag,
      keyLength: keyLength,
      valueLength: valueLength,
    );
  }

  static Map<String, dynamic> decodeWithCrc(Uint8List data) {
    final header = decodeHeader(data.sublist(0, headerSize));

    final keyStart = headerSize;
    final keyEnd = keyStart + header.keyLength;

    final valueStart = keyEnd;
    final valueEnd = valueStart + header.valueLength;

    return {
      'deleted': header.deleted,
      'key': Uint8List.fromList(data.sublist(keyStart, keyEnd)),
      'value': Uint8List.fromList(data.sublist(valueStart, valueEnd)),
    };
  }

  static Uint8List _uint32(int value) {
    final b = ByteData(4);
    b.setUint32(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _readUint32(Uint8List data, int offset) {
    return ByteData.sublistView(data, offset, offset + 4)
        .getUint32(0, Endian.big);
  }
}