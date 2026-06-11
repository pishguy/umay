import 'dart:typed_data';
import 'dart:convert';

class BinaryWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeInt(int value) {
    final data = ByteData(4);
    data.setInt32(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeBool(bool value) {
    _builder.addByte(value ? 1 : 0);
  }

  void writeDouble(double value) {
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.big);
    _builder.add(data.buffer.asUint8List());
  }

  void writeString(String value) {
    final bytes = utf8.encode(value);
    writeInt(bytes.length);
    _builder.add(bytes);
  }

  void writeBytes(Uint8List bytes) {
    writeInt(bytes.length);
    _builder.add(bytes);
  }

  Uint8List toBytes() {
    return _builder.toBytes();
  }
}
