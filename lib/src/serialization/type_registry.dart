import 'type_adapter.dart';

/// A registry that maps type IDs to their corresponding [TypeAdapter]s
/// and maintains a reverse lookup from Dart [Type] to type ID.
class TypeRegistry {
  static final Map<int, TypeAdapter<dynamic>> _adapters = {};
  static final Map<Type, int> _typeIds = {};

  /// Registers an [adapter] so it can be used for serialization and
  /// deserialization of the associated type.
  static void registerAdapter<T>(TypeAdapter<T> adapter) {
    _adapters[adapter.typeId] = adapter;
    _typeIds[T] = adapter.typeId;
  }

  /// Returns the [TypeAdapter] registered for [typeId], or `null` if
  /// no adapter has been registered for that id.
  static TypeAdapter<dynamic>? getAdapter(int typeId) {
    return _adapters[typeId];
  }

  /// Lookup typeId by runtime type of [value].
  static int? findTypeIdFor(Object value) {
    return _typeIds[value.runtimeType];
  }
}