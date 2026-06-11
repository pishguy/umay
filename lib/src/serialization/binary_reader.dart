import 'dart:typed_data';
import 'dart:convert';

class BinaryReader {
  final Uint8List _data;
  int _offset = 0;

  BinaryReader(this._data);

  int readInt() {
    final value = ByteData.sublistView(_data, _offset, _offset + 4)
        .getInt32(0, Endian.big);
    _offset += 4;
    return value;
  }

  bool readBool() {
    final value = _data[_offset] == 1;
    _offset += 1;
    return value;
  }

  double readDouble() {
    final value = ByteData.sublistView(_data, _offset, _offset + 8)
        .getFloat64(0, Endian.big);
    _offset += 8;
    return value;
  }

  String readString() {
    final length = readInt();
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return utf8.decode(bytes);
  }

  Uint8List readBytes() {
    final length = readInt();
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(bytes);
  }
}
