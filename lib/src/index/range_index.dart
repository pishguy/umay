import 'bplus_tree.dart';
import 'index_key.dart';

class RangeIndex {
  final String field;
  final BPlusTree<IndexKey, String> tree;

  RangeIndex(this.field) : tree = BPlusTree<IndexKey, String>();

  // ---- Insert ----
  void add(Comparable value, String primaryKey) {
    tree.put(IndexKey(value), primaryKey);
  }

  // ---- Remove ----
  void remove(Comparable value) {
    tree.remove(IndexKey(value));
  }

  // ---- Greater Than ----
  Set<String> greaterThan(Comparable value) {
    final result = <String>{};

    var start = IndexKey(value);

    // مقدار انتهایی خیلی بزرگ، همیشه بزرگ‌تر از همه
    var end = IndexKey(_InfinityComparable());

    for (var entry in tree.range(start, end)) {
      if (entry.key.compareTo(start) > 0) {
        result.add(entry.value);
      }
    }

    return result;
  }


  // ---- Between ----
  Set<String> between(Comparable a, Comparable b) {
    final result = <String>{};

    for (var entry in tree.range(IndexKey(a), IndexKey(b))) {
      result.add(entry.value);
    }

    return result;
  }
}


class _InfinityComparable implements Comparable {
  @override
  int compareTo(other) => 1; // همیشه بزرگ‌تر
}
