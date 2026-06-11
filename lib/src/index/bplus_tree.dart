import 'dart:math';
import 'bplus_node.dart';

class BPlusTree<K extends Comparable<K>, V> {
  final int order;
  final int minKeys;
  BPlusNode<K, V>? _root;

  BPlusTree({this.order = 32}) : minKeys = (order / 2).ceil();

  BPlusNode<K, V>? get root => _root;

  // ------------------- جستجو -------------------

  V? get(K key) {
    if (_root == null) return null;
    var leaf = _findLeaf(key);
    int idx = leaf.findKeyIndex(key);
    return idx >= 0 ? leaf.values[idx] : null;
  }

  BPlusLeaf<K, V> _findLeaf(K key) {
    var curr = _root!;
    while (curr is BPlusInternal<K, V>) {
      int idx = curr.findChildIndex(key);
      curr = curr.children[idx];
    }
    return curr as BPlusLeaf<K, V>;
  }

  // ------------------- درج (Insert) -------------------

  void put(K key, V value) {
    if (_root == null) {
      _root = BPlusLeaf([key], [value]);
      return;
    }

    var leaf = _findLeaf(key);
    int idx = leaf.findKeyIndex(key);

    if (idx >= 0) {
      leaf.values[idx] = value; // Update
    } else {
      int insertIdx = -(idx + 1);
      leaf.keys.insert(insertIdx, key);
      leaf.values.insert(insertIdx, value);

      if (leaf.keys.length > order) {
        _splitLeaf(leaf);
      }
    }
  }

  void _splitLeaf(BPlusLeaf<K, V> leaf) {
    int mid = (leaf.keys.length / 2).floor();

    var newLeaf = BPlusLeaf(
      leaf.keys.sublist(mid),
      leaf.values.sublist(mid),
      parent: leaf.parent,
      next: leaf.next,
      prev: leaf,
    );

    leaf.next?.prev = newLeaf;
    leaf.next = newLeaf;

    leaf.keys.removeRange(mid, leaf.keys.length);
    leaf.values.removeRange(mid, leaf.values.length);

    _insertIntoParent(leaf, newLeaf.keys[0], newLeaf);
  }

  void _insertIntoParent(BPlusNode<K, V> left, K key, BPlusNode<K, V> right) {
    if (left.isRoot) {
      _root = BPlusInternal([key], [left, right]);
      left.parent = _root as BPlusInternal<K, V>;
      right.parent = _root as BPlusInternal<K, V>;
      return;
    }

    var parent = left.parent!;
    int idx = parent.findChildIndex(key);
    parent.keys.insert(idx, key);
    parent.children.insert(idx + 1, right);
    right.parent = parent;

    if (parent.keys.length > order) {
      _splitInternal(parent);
    }
  }

  void _splitInternal(BPlusInternal<K, V> node) {
    int mid = (node.keys.length / 2).floor();
    K upKey = node.keys[mid];

    var newNode = BPlusInternal(
      node.keys.sublist(mid + 1),
      node.children.sublist(mid + 1),
      parent: node.parent,
    );

    node.keys.removeRange(mid, node.keys.length);
    node.children.removeRange(mid + 1, node.children.length);

    _insertIntoParent(node, upKey, newNode);
  }

  // ------------------- حذف و Rebalance کامل -------------------

  void remove(K key) {
    if (_root == null) return;
    var leaf = _findLeaf(key);
    int idx = leaf.findKeyIndex(key);
    if (idx < 0) return;

    leaf.keys.removeAt(idx);
    leaf.values.removeAt(idx);

    if (leaf.isRoot) {
      if (leaf.keys.isEmpty) _root = null;
      return;
    }

    if (leaf.keys.length < minKeys) {
      _rebalance(leaf);
    } else if (idx == 0 && leaf.prev != null) {
      // اگر اولین کلید حذف شد، باید ایندکس والد آپدیت شود
      _updateParentKey(leaf, key, leaf.keys[0]);
    }
  }

  void _rebalance(BPlusNode<K, V> node) {
    if (node.isRoot) {
      if (!node.isLeaf && node.keys.isEmpty) {
        _root = (node as BPlusInternal<K, V>).children[0];
        _root!.parent = null;
      }
      return;
    }

    var parent = node.parent!;
    int idx = parent.children.indexOf(node);

    // ۱. قرض گرفتن از همسایه چپ
    if (idx > 0) {
      var leftSibling = parent.children[idx - 1];
      if (leftSibling.keys.length > minKeys) {
        _borrowFromLeft(node, leftSibling, parent, idx - 1);
        return;
      }
    }

    // ۲. قرض گرفتن از همسایه راست
    if (idx < parent.children.length - 1) {
      var rightSibling = parent.children[idx + 1];
      if (rightSibling.keys.length > minKeys) {
        _borrowFromRight(node, rightSibling, parent, idx);
        return;
      }
    }

    // ۳. ادغام (Merge)
    if (idx > 0) {
      _merge(parent.children[idx - 1], node, parent, idx - 1);
    } else {
      _merge(node, parent.children[idx + 1], parent, idx);
    }
  }

  void _borrowFromLeft(BPlusNode<K, V> node, BPlusNode<K, V> sibling, BPlusInternal<K, V> parent, int parentKeyIdx) {
    if (node is BPlusLeaf<K, V>) {
      var leaf = node;
      var sib = sibling as BPlusLeaf<K, V>;
      leaf.keys.insert(0, sib.keys.removeLast());
      leaf.values.insert(0, sib.values.removeLast());
      parent.keys[parentKeyIdx] = leaf.keys[0];
    } else {
      var internal = node as BPlusInternal<K, V>;
      var sib = sibling as BPlusInternal<K, V>;
      internal.keys.insert(0, parent.keys[parentKeyIdx]);
      parent.keys[parentKeyIdx] = sib.keys.removeLast();
      var child = sib.children.removeLast();
      internal.children.insert(0, child);
      child.parent = internal;
    }
  }

  void _borrowFromRight(BPlusNode<K, V> node, BPlusNode<K, V> sibling, BPlusInternal<K, V> parent, int parentKeyIdx) {
    if (node is BPlusLeaf<K, V>) {
      var leaf = node;
      var sib = sibling as BPlusLeaf<K, V>;
      leaf.keys.add(sib.keys.removeAt(0));
      leaf.values.add(sib.values.removeAt(0));
      parent.keys[parentKeyIdx] = sib.keys[0];
    } else {
      var internal = node as BPlusInternal<K, V>;
      var sib = sibling as BPlusInternal<K, V>;
      internal.keys.add(parent.keys[parentKeyIdx]);
      parent.keys[parentKeyIdx] = sib.keys.removeAt(0);
      var child = sib.children.removeAt(0);
      internal.children.add(child);
      child.parent = internal;
    }
  }

  void _merge(BPlusNode<K, V> left, BPlusNode<K, V> right, BPlusInternal<K, V> parent, int parentKeyIdx) {
    if (left is BPlusLeaf<K, V>) {
      var l = left;
      var r = right as BPlusLeaf<K, V>;
      l.keys.addAll(r.keys);
      l.values.addAll(r.values);
      l.next = r.next;
      r.next?.prev = l;
    } else {
      var l = left as BPlusInternal<K, V>;
      var r = right as BPlusInternal<K, V>;
      l.keys.add(parent.keys[parentKeyIdx]);
      l.keys.addAll(r.keys);
      for (var child in r.children) {
        child.parent = l;
        l.children.add(child);
      }
    }

    parent.keys.removeAt(parentKeyIdx);
    parent.children.removeAt(parentKeyIdx + 1);

    if (parent.keys.length < minKeys) {
      _rebalance(parent);
    }
  }

  void _updateParentKey(BPlusLeaf<K, V> leaf, K oldKey, K newKey) {
    var curr = leaf.parent;
    while (curr != null) {
      int idx = curr.findKeyIndex(oldKey);
      if (idx >= 0) {
        curr.keys[idx] = newKey;
        return;
      }
      curr = curr.parent;
    }
  }

  // ------------------- Range Queries -------------------

  Iterable<MapEntry<K, V>> range(K start, K end) sync* {
    if (_root == null) return;
    var leaf = _findLeaf(start);

    bool finished = false;
    while (!finished) {
      for (int i = 0; i < leaf.keys.length; i++) {
        if (leaf.keys[i].compareTo(start) >= 0) {
          if (leaf.keys[i].compareTo(end) <= 0) {
            yield MapEntry(leaf.keys[i], leaf.values[i]);
          } else {
            finished = true;
            break;
          }
        }
      }
      if (leaf.next == null) break;
      leaf = leaf.next!;
    }
  }
}
