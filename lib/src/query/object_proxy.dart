import 'expressions.dart';

T _makeProxy<T>(FieldExpr Function(String) getField) {
  return _Proxy<T>(getField) as T;
}

class _Proxy<T> extends Object {
  final FieldExpr Function(String) getField;

  _Proxy(this.getField);

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.isGetter) {
      final name = i.memberName.toString()
          .replaceAll("Symbol(\"", "")
          .replaceAll("\")", "");

      return getField(name);
    }
    throw UnimplementedError("Only getters are supported");
  }
}
