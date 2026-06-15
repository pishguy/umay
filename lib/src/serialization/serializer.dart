import 'dart:typed_data';

import 'binary_reader.dart';
import 'binary_writer.dart';
import 'type_registry.dart';

/// Provides static methods for serializing and deserializing objects
/// to and from binary format using registered [TypeAdapter]s.
class Serializer {
  /// Serializes [obj] with the given [typeId] into a binary byte buffer.
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

  /// Deserializes a binary byte buffer back into an object using the
  /// adapter registered for the type id stored in the buffer.
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
