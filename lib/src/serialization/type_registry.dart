import 'type_adapter.dart';

class TypeRegistry {
  static final Map<int, TypeAdapter<dynamic>> _adapters = {};
  static final Map<Type, int> _typeIds = {};

  static void registerAdapter<T>(TypeAdapter<T> adapter) {
    _adapters[adapter.typeId] = adapter;
    _typeIds[T] = adapter.typeId;
  }

  static TypeAdapter<dynamic>? getAdapter(int typeId) {
    return _adapters[typeId];
  }

  /// Lookup typeId by runtime type of [value].
  static int? findTypeIdFor(Object value) {
    return _typeIds[value.runtimeType];
  }
}