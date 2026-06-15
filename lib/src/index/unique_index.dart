import 'bplus_node.dart';
import 'bplus_tree.dart';

/// A B+ tree-backed index that enforces unique keys.
///
/// Maps a unique key of type `K` to a single value of type `V`.
/// Supports insertion, lookup, removal, containment checks, and
/// sequential iteration over all values.
class UniqueIndex<K extends Comparable<K>, V> {
  final BPlusTree<K, V> _tree;

  /// The field name this unique index is defined on.
  final String name;

  UniqueIndex(this.name, {int order = 32}) : _tree = BPlusTree<K, V>(order: order);

  /// Inserts or updates the mapping from [key] to [value].
  void put(K key, V value) => _tree.put(key, value);

  /// Returns the value associated with [key], or null if not present.
  V? get(K key) => _tree.get(key);

  /// Removes the mapping for [key] from the index.
  void remove(K key) => _tree.remove(key);

  /// Returns true if [key] is present in the index.
  bool contains(K key) => _tree.get(key) != null;

  /// Returns an iterable over all values in the index, in key order.
  Iterable<V> getAll() sync* {
    var curr = _tree.root;
    if (curr == null) return;

    // حرکت به چپ‌ترین برگ
    while (curr is BPlusInternal<K, V>) {
      curr = curr.children.first;
    }

    var leaf = curr as BPlusLeaf<K, V>?;
    while (leaf != null) {
      for (var v in leaf.values) {
        yield v;
      }

      leaf = leaf.next;
    }
  }

}
