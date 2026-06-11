import 'dart:typed_data';

import 'binary_reader.dart';
import 'binary_writer.dart';
import 'type_registry.dart';
import 'type_adapter.dart';

class Serializer {
  static Uint8List serialize(Object obj, int typeId) {
    final adapter = TypeRegistry.getAdapter(typeId);

    if (adapter == null) {
      throw Exception("No adapter registered for typeId $typeId");
    }

    final writer = BinaryWriter();

    writer.writeInt(typeId);
    adapter.write(writer, obj);

    return writer.toBytes();
  }

  static dynamic deserialize(Uint8List bytes) {
    final reader = BinaryReader(bytes);

    final typeId = reader.readInt();
    final adapter = TypeRegistry.getAdapter(typeId);

    if (adapter == null) {
      throw Exception("No adapter registered for typeId $typeId");
    }

    return adapter.read(reader);
  }
}
