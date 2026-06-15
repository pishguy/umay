import 'expressions.dart';

/// Builds a dynamic proxy object that captures field selectors for query building.
class ProxyBuilder<T> {
  final Map<String, FieldExpr> _fields = {};

  /// Creates and returns a dynamic proxy object that intercepts property reads.
  dynamic build() {
    return _ProxyObject(_resolveField);
  }

  FieldExpr _resolveField(String name) {
    return _fields.putIfAbsent(name, () => FieldExpr(name));
  }

  /// The list of field expressions captured by the proxy.
  List<FieldExpr> get fields => _fields.values.toList();
}

class _ProxyObject {
  final FieldExpr Function(String) resolver;

  _ProxyObject(this.resolver);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final fieldName = _symbolToString(invocation.memberName);

      return resolver(fieldName);
    }

    return super.noSuchMethod(invocation);
  }

  String _symbolToString(Symbol symbol) {
    final s = symbol.toString();
    return s.substring(8, s.length - 2);
  }
}
