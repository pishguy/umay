class PivotTable {

  final Map<dynamic, Set<dynamic>> forward = {};
  final Map<dynamic, Set<dynamic>> reverse = {};

  void attach(dynamic a, dynamic b) {

    forward.putIfAbsent(a, () => {}).add(b);
    reverse.putIfAbsent(b, () => {}).add(a);
  }

  void detach(dynamic a, dynamic b) {

    forward[a]?.remove(b);
    reverse[b]?.remove(a);
  }

  Set<dynamic>? getForward(dynamic a) {
    return forward[a];
  }

  Set<dynamic>? getReverse(dynamic b) {
    return reverse[b];
  }
}
