import 'bplus_tree.dart';
import 'composite_key.dart';

/// A compound (composite) index over multiple fields using a B+ tree.
///
/// Supports exact-match lookup across all indexed fields, as well as
/// range queries. Duplicate composite keys are handled by storing
/// sets of record keys.
class CompoundIndex {
  /// The list of field names this compound index spans.
  final List<String> fields;

  /// The underlying B+ tree mapping composite keys to sets of record keys.
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

  /// Indexes [obj] under the composite key derived from its fields, associated with [key].
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

  /// Removes the association of [key] from the composite key derived from [obj].
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

  /// Searches for records whose fields exactly match [query].
  ///
  /// Returns the list of record keys that match, or an empty list if none found.
  List<String> search(Map<String, dynamic> query) {
    if (!_isValid(query)) return const [];

    final composite = _buildKey(query);
    final v = tree.get(composite);
    if (v == null) return const [];

    return v.toList();
  }

  /// Queries the range of composite keys between [start] (inclusive) and [end] (inclusive).
  ///
  /// Returns all record keys whose composite key falls within the range.
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