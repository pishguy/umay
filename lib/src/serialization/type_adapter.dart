import 'binary_reader.dart';
import 'binary_writer.dart';

abstract class TypeAdapter<T> {
  int get typeId;

  T read(BinaryReader reader);

  void write(BinaryWriter writer, T obj);
}
