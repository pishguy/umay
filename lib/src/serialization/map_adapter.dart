import 'binary_reader.dart';
import 'binary_writer.dart';
import 'type_adapter.dart';

/// A [TypeAdapter] for [Map<String, dynamic>] that serializes map
/// entries (keys and values of primitive types) to and from binary.
class MapAdapter extends TypeAdapter<Map<String, dynamic>> {
  @override
  int get typeId => 0;

  /// Reads a map with string keys and dynamic values from the [reader].
  @override
  Map<String, dynamic> read(BinaryReader reader) {
    final length = reader.readInt();
    final map = <String, dynamic>{};
    for (var i = 0; i < length; i++) {
      final key = reader.readString();
      final value = _readValue(reader);
      map[key] = value;
    }
    return map;
  }

  /// Writes [obj] (a map with string keys) to the [writer] in binary format.
  @override
  void write(BinaryWriter writer, Map<String, dynamic> obj) {
    writer.writeInt(obj.length);
    for (final entry in obj.entries) {
      writer.writeString(entry.key);
      _writeValue(writer, entry.value);
    }
  }

  void _writeValue(BinaryWriter writer, dynamic value) {
    if (value == null) {
      writer.writeInt(-1);
    } else if (value is String) {
      writer.writeInt(0);
      writer.writeString(value);
    } else if (value is int) {
      writer.writeInt(1);
      writer.writeInt(value);
    } else if (value is double) {
      writer.writeInt(2);
      writer.writeDouble(value);
    } else if (value is bool) {
      writer.writeInt(3);
      writer.writeBool(value);
    } else if (value is Map<String, dynamic>) {
      writer.writeInt(4);
      write(writer, value);
    } else {
      writer.writeInt(0);
      writer.writeString(value.toString());
    }
  }

  dynamic _readValue(BinaryReader reader) {
    final type = reader.readInt();
    switch (type) {
      case -1: return null;
      case 0:  return reader.readString();
      case 1:  return reader.readInt();
      case 2:  return reader.readDouble();
      case 3:  return reader.readBool();
      case 4:  return read(reader);
      default: return reader.readString();
    }
  }
}
