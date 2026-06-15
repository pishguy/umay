import 'binary_reader.dart';
import 'binary_writer.dart';

/// A [TypeAdapter] handles serialization and deserialization of objects
/// of type [T] to and from binary format.
abstract class TypeAdapter<T> {
  /// The unique integer identifier for the type handled by this adapter.
  int get typeId;

  /// Reads and returns an instance of [T] from the [reader].
  T read(BinaryReader reader);

  /// Writes [obj] to the [writer] in binary format.
  void write(BinaryWriter writer, T obj);
}
