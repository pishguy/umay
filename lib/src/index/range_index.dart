import 'bplus_tree.dart';
import 'index_key.dart';

/// A B+ tree-backed index that supports range queries over a single field.
///
/// Maps field values to primary keys and provides efficient
/// greater-than and between-range lookups.
class RangeIndex {
  /// The field name being indexed.
  final String field;

  /// The underlying B+ tree mapping index keys to primary keys.
  final BPlusTree<IndexKey, String> tree;

  RangeIndex(this.field) : tree = BPlusTree<IndexKey, String>();

  /// Indexes [value] and associates it with [primaryKey].
  void add(Comparable value, String primaryKey) {
    tree.put(IndexKey(value), primaryKey);
  }

  /// Removes the entry for [value] from the index.
  void remove(Comparable value) {
    tree.remove(IndexKey(value));
  }

  /// Returns the set of primary keys whose indexed value is strictly greater than [value].
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


  /// Returns the set of primary keys whose indexed value falls between [a] and [b] (inclusive).
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
