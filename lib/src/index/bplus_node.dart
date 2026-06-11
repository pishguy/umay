abstract class BPlusNode<K extends Comparable<K>, V> {
  final List<K> keys;
  BPlusInternal<K, V>? parent;

  BPlusNode(this.keys, {this.parent});

  bool get isLeaf;
  bool get isRoot => parent == null;

  int findKeyIndex(K key) {
    int low = 0;
    int high = keys.length - 1;

    while (low <= high) {
      int mid = (low + high) >> 1;
      int cmp = keys[mid].compareTo(key);
      if (cmp == 0) return mid;
      if (cmp < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return -(low + 1); // برگرداندن ایندکس درج در صورت پیدا نشدن
  }
}

/// نودهای میانی (Internal) - فقط شامل کلید و اشاره‌گر به فرزندان
class BPlusInternal<K extends Comparable<K>, V> extends BPlusNode<K, V> {
  final List<BPlusNode<K, V>> children;

  BPlusInternal(super.keys, this.children, {super.parent}) {
    for (var child in children) {
      child.parent = this;
    }
  }

  @override
  bool get isLeaf => false;

  /// پیدا کردن فرزندی که کلید ممکن است در آن باشد
  int findChildIndex(K key) {
    int low = 0;
    int high = keys.length - 1;
    while (low <= high) {
      int mid = (low + high) >> 1;
      if (key.compareTo(keys[mid]) < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }
}

class BPlusLeaf<K extends Comparable<K>, V> extends BPlusNode<K, V> {
  final List<V> values;
  BPlusLeaf<K, V>? next;
  BPlusLeaf<K, V>? prev;

  BPlusLeaf(super.keys, this.values,
      {super.parent, this.next, this.prev});

  @override
  bool get isLeaf => true;
}
