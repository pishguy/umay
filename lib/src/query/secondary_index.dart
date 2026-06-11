import 'dart:collection';

class SecondaryIndex<T extends Comparable> {

  final String field;

  final Map<T, Set<String>> _map = {};
  final SplayTreeMap<T, Set<String>> _tree = SplayTreeMap();

  SecondaryIndex(this.field);

  void add(T? value, String key) {
    if (value == null) return;

    final set = _map.putIfAbsent(value, () => <String>{});
    set.add(key);

    final treeSet = _tree.putIfAbsent(value, () => <String>{});
    treeSet.add(key);
  }

  void remove(T? value, String key) {
    if (value == null) return;

    final set = _map[value];
    if (set != null) {
      set.remove(key);
      if (set.isEmpty) {
        _map.remove(value);
      }
    }

    final treeSet = _tree[value];
    if (treeSet != null) {
      treeSet.remove(key);
      if (treeSet.isEmpty) {
        _tree.remove(value);
      }
    }
  }

  void update(T? oldValue, T? newValue, String key) {
    if (oldValue != null) {
      remove(oldValue, key);
    }

    if (newValue != null) {
      add(newValue, key);
    }
  }

  Set<String>? get(T value) {
    return _map[value];
  }

  bool contains(T value) {
    return _map.containsKey(value);
  }

  Iterable<String> range(T min, T max) sync* {
    for (final entry in _tree.entries) {
      final key = entry.key;

      if (key.compareTo(min) >= 0 && key.compareTo(max) <= 0) {
        yield* entry.value;
      }
    }
  }

  Iterable<String> rangeStart(T min) sync* {
    for (final entry in _tree.entries) {
      if (entry.key.compareTo(min) >= 0) {
        yield* entry.value;
      }
    }
  }

  Iterable<String> rangeEnd(T max) sync* {
    for (final entry in _tree.entries) {
      if (entry.key.compareTo(max) <= 0) {
        yield* entry.value;
      }
    }
  }

  Iterable<String> values() sync* {
    for (final set in _map.values) {
      yield* set;
    }
  }

  int get size => _map.length;

  void clear() {
    _map.clear();
    _tree.clear();
  }
}
