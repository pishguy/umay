import 'bplus_node.dart';
import 'bplus_tree.dart';

class UniqueIndex<K extends Comparable<K>, V> {
  final BPlusTree<K, V> _tree;
  final String name;

  UniqueIndex(this.name, {int order = 32}) : _tree = BPlusTree<K, V>(order: order);

  void put(K key, V value) => _tree.put(key, value);

  V? get(K key) => _tree.get(key);

  void remove(K key) => _tree.remove(key);

  bool contains(K key) => _tree.get(key) != null;

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
