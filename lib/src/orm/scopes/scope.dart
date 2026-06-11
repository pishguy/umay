import '../../query/query_builder.dart';

abstract class Scope<T> {
  void apply(QueryBuilder query);
}

class ScopeRegistry {
  final List<Scope> scopes = [];

  void add(Scope scope) {
    scopes.add(scope);
  }

  void applyAll(QueryBuilder builder) {
    for (final s in scopes) {
      s.apply(builder);
    }
  }
}
