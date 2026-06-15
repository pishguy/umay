import 'dart:async';
import 'dart:collection';

import '../query/filter.dart';
import '../utils/levenshtein.dart';
import '../utils/text_normalizer.dart';
import 'change_event.dart';

class SmartQueryWatcher<T> {
  final Stream<ChangeEvent> changes;
  final List<Filter> filters;
  final Future<T?> Function(String key) getObject;
  final List<String> Function() getAllKeys;
  final Future<List<T>> Function() initialRun;
  final bool sortDescending;
  final String? sortField;
  final Map<String, dynamic> Function(T obj) toMap;

  final StreamController<List<T>> _controller =
  StreamController<List<T>>.broadcast();

  late final StreamSubscription _subscription;

  final Map<String, T> _itemsByKey = {};
  late final SplayTreeSet<T> _sorted;

  bool _disposed = false;

  SmartQueryWatcher({
    required this.changes,
    required this.filters,
    required this.getObject,
    required this.getAllKeys,
    required this.initialRun,
    required this.toMap,
    this.sortField,
    this.sortDescending = false,
  }) {
    _sorted = SplayTreeSet<T>(_compare);

    _subscription = changes.listen(_onChange);

    _runInitial();
  }

  Future<void> _runInitial() async {
    try {
      final initialResults = await initialRun();

      if (_disposed) return;

      for (final obj in initialResults) {
        final id = toMap(obj)['id'];
        if (id == null) continue;
        _itemsByKey[id.toString()] = obj;
        _sorted.add(obj);
      }
      _emit();
    } catch (_) {
      // اگه initialRun شکست، stream رو نبند
    }
  }

  int _compare(T a, T b) {
    int result = 0;

    if (sortField != null) {
      final av = toMap(a)[sortField];
      final bv = toMap(b)[sortField];
      result = _compareValues(av, bv);
      if (sortDescending) result = -result;
    }

    // tiebreaker: دو object مختلف هرگز equal نباشن
    if (result == 0) {
      final idA = toMap(a)['id']?.toString() ?? '';
      final idB = toMap(b)['id']?.toString() ?? '';
      result = idA.compareTo(idB);
    }

    return result;
  }

  Future<void> _onChange(ChangeEvent e) async {
    if (_disposed) return;

    final key = e.key;
    final existed = _itemsByKey.containsKey(key);

    T? newObj;

    if (e.type == ChangeType.delete) {
      newObj = null;
    } else {
      newObj = e.newValue is T ? e.newValue as T : await getObject(key);
    }

    if (_disposed) return;

    final isMatching = newObj != null && _match(newObj);

    if (existed && !isMatching) {
      final old = _itemsByKey[key];
      if (old == null) return;
      _sorted.remove(old);
      _itemsByKey.remove(key);
      _emit();
      return;
    }

    if (!existed && isMatching) {
      _itemsByKey[key] = newObj;
      _sorted.add(newObj);
      _emit();
      return;
    }

    if (existed && isMatching) {
      final old = _itemsByKey[key];
      if (old == null) return;
      _sorted.remove(old);
      _itemsByKey[key] = newObj;
      _sorted.add(newObj);
      _emit();
    }
  }

  bool _match(T obj) {
    final map = toMap(obj);

    for (final f in filters) {
      final value = map[f.field];

      if (f.eq != null && value != f.eq) return false;

      if (f.gt != null) {
        final cmp = _nullableCompare(value, f.gt);
        if (cmp == null || cmp <= 0) return false;
      }
      if (f.lt != null) {
        final cmp = _nullableCompare(value, f.lt);
        if (cmp == null || cmp >= 0) return false;
      }
      if (f.gte != null) {
        final cmp = _nullableCompare(value, f.gte);
        if (cmp == null || cmp < 0) return false;
      }
      if (f.lte != null) {
        final cmp = _nullableCompare(value, f.lte);
        if (cmp == null || cmp > 0) return false;
      }

      if (f.contains != null &&
          (value is! String || !value.contains(f.contains!))) {
        return false;
      }
      if (f.startsWith != null &&
          (value is! String || !value.startsWith(f.startsWith!))) {
        return false;
      }
      if (f.endsWith != null &&
          (value is! String || !value.endsWith(f.endsWith!))) {
        return false;
      }

      if (f.inValues != null && !f.inValues!.contains(value)) {
        return false;
      }

      if (f.isNull == true && value != null) return false;

      if (f.betweenStart != null) {
        final cmp = _nullableCompare(value, f.betweenStart);
        if (cmp == null || cmp < 0) return false;
      }
      if (f.betweenEnd != null) {
        final cmp = _nullableCompare(value, f.betweenEnd);
        if (cmp == null || cmp > 0) return false;
      }

      if (f.fuzzy != null) {
        if (value is! String) return false;
        final q = TextNormalizer.normalize(f.fuzzy!);
        final text = TextNormalizer.normalize(value);
        final maxLen =
        q.length > text.length ? q.length : text.length;
        if (maxLen == 0) continue;
        final dist = Levenshtein.distance(q, text);
        final score = 1 - (dist / maxLen);
        if (score < (f.fuzzyThreshold ?? 0.6)) return false;
      }
    }

    return true;
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a is Comparable && b is Comparable) {
      try {
        return a.compareTo(b);
      } catch (_) {}
    }
    return a.toString().compareTo(b.toString());
  }

  int? _nullableCompare(dynamic a, dynamic b) {
    if (a == null || b == null) return null;
    return _compareValues(a, b);
  }

  void _emit() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(_sorted.toList(growable: false));
  }

  Stream<List<T>> get stream => _controller.stream;

  void dispose() {
    if (_disposed) return; // جلوگیری از double-dispose
    _disposed = true;
    _subscription.cancel();
    _controller.close();
  }
}