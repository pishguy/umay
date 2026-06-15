/// An in-memory pivot table storing many-to-many relationship links.
class PivotTable {

  /// Maps parent keys to sets of related keys.
  final Map<dynamic, Set<dynamic>> forward = {};

  /// Maps related keys to sets of parent keys.
  final Map<dynamic, Set<dynamic>> reverse = {};

  /// Creates a link between entity [a] and entity [b].
  void attach(dynamic a, dynamic b) {

    forward.putIfAbsent(a, () => {}).add(b);
    reverse.putIfAbsent(b, () => {}).add(a);
  }

  /// Removes the link between entity [a] and entity [b].
  void detach(dynamic a, dynamic b) {

    forward[a]?.remove(b);
    reverse[b]?.remove(a);
  }

  /// Returns the set of related keys for a given parent key [a].
  Set<dynamic>? getForward(dynamic a) {
    return forward[a];
  }

  /// Returns the set of parent keys for a given related key [b].
  Set<dynamic>? getReverse(dynamic b) {
    return reverse[b];
  }
}
