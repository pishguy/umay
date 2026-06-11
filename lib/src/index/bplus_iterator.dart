import 'bplus_node.dart';

class BPlusIterator<K extends Comparable<K>, V> implements Iterator<V> {
  BPlusLeaf<K, V>? _leaf;
  int _index = -1;

  BPlusIterator(this._leaf);

  @override
  V get current => _leaf!.values[_index];

  @override
  bool moveNext() {
    if (_leaf == null) return false;

    _index++;

    if (_index < _leaf!.values.length) {
      return true;
    }

    // Move to next leaf
    _leaf = _leaf!.next;
    _index = 0;

    if (_leaf == null || _leaf!.values.isEmpty) {
      return false;
    }

    return true;
  }
}