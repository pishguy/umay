import 'dart:collection';

class RangeIndex {
  final SplayTreeMap<num, Set<String>> _tree = SplayTreeMap();

  void add(num value, String key) {
    _tree.putIfAbsent(value, () => {}).add(key);
  }

  Set<String> greaterThan(num value) {
    final result = <String>{};

    for (final entry in _tree.entries) {
      if (entry.key > value) {
        result.addAll(entry.value);
      }
    }

    return result;
  }
}
