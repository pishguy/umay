import 'bplus_tree.dart';
import 'composite_key.dart';

///    to support duplicate composite keys
class CompoundIndex {
  final List<String> fields;
  final BPlusTree<CompositeKey, Set<String>> tree;

  CompoundIndex(this.fields, {int order = 32})
      : tree = BPlusTree(order: order);

  bool _isValid(Map<String, dynamic> obj) {
    for (final f in fields) {
      if (!obj.containsKey(f) || obj[f] == null) return false;
    }
    return true;
  }

  CompositeKey _buildKey(Map<String, dynamic> obj) {
    return CompositeKey(
      fields.map((f) => obj[f] as Comparable).toList(),
    );
  }

  void insert(Map<String, dynamic> obj, String key) {
    if (!_isValid(obj)) return;
    final composite = _buildKey(obj);

    final existing = tree.get(composite);
    if (existing != null) {
      existing.add(key);
    } else {
      tree.put(composite, {key});
    }
  }

  void remove(Map<String, dynamic> obj, String key) {
    if (!_isValid(obj)) return;
    final composite = _buildKey(obj);

    final existing = tree.get(composite);
    if (existing != null) {
      existing.remove(key);
      if (existing.isEmpty) {
        tree.remove(composite);
      }
    }
  }

  List<String> search(Map<String, dynamic> query) {
    if (!_isValid(query)) return const [];

    final composite = _buildKey(query);
    final v = tree.get(composite);
    if (v == null) return const [];

    return v.toList();
  }

  List<String> range(
      Map<String, dynamic> start,
      Map<String, dynamic> end,
      ) {
    if (!_isValid(start) || !_isValid(end)) return const [];

    final startKey = _buildKey(start);
    final endKey = _buildKey(end);

    final result = <String>[];
    for (var entry in tree.range(startKey, endKey)) {
      result.addAll(entry.value);
    }
    return result;
  }
}