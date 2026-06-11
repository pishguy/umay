import 'scope.dart';

class ScopeRegistry {

  final List<Scope> globalScopes = [];

  final Map<String, Scope> localScopes = {};

  void addGlobal(Scope scope) {
    globalScopes.add(scope);
  }

  void addLocal(String name, Scope scope) {
    localScopes[name] = scope;
  }

}
