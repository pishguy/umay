import 'compound_index.dart';
import 'unique_index.dart';
import 'fuzzy_index.dart';
import '../query/secondary_index.dart';

class IndexManager {
  final Map<String, SecondaryIndex> secondaryIndexes = {};
  final List<CompoundIndex> compoundIndexes = [];
  final List<UniqueIndex> uniqueIndexes = [];
  final Map<String, FuzzyIndex<String>> fuzzyIndexes = {};
  final List<CompoundIndex> compositeIndexes = [];

  // CREATE INDEXES

  void createIndex(String field) {
    secondaryIndexes[field] = SecondaryIndex(field);
  }

  void createCompositeIndex(List<String> fields) {
    compoundIndexes.add(CompoundIndex(fields));
  }

  void createUniqueIndex<T extends Comparable<T>>(String field) {
    uniqueIndexes.add(UniqueIndex<T, String>(field));
  }


  void createFuzzyIndex(String field) {
    fuzzyIndexes[field] = FuzzyIndex<String>();
  }

  // PUT

  void onPut(Map<String, dynamic> obj, String key) {
    // secondary
    for (final index in secondaryIndexes.values) {
      final value = obj[index.field];
      if (value != null) {
        index.add(value, key);
      }
    }

    // composite
    for (final index in compoundIndexes) {
      index.insert(obj, key);
    }

    // unique (value = key)
    for (final index in uniqueIndexes) {
      final value = obj[index.name];
      if (value != null && value is Comparable) {
        index.put(value, key);
      }
    }

    // fuzzy
    for (final entry in fuzzyIndexes.entries) {
      final text = obj[entry.key];
      if (text is String) {
        entry.value.add(text, key);
      }
    }
  }

  // DELETE

  void onDelete(Map<String, dynamic> obj, String key) {
    // secondary
    for (final index in secondaryIndexes.values) {
      final value = obj[index.field];
      if (value != null) index.remove(value, key);
    }

    // composite
    for (final index in compoundIndexes) {
      index.remove(obj, key);
    }

    // unique
    for (final index in uniqueIndexes) {
      final value = obj[index.name];
      if (value != null && value is Comparable) {
        index.remove(value);
      }
    }

    // fuzzy
    for (final entry in fuzzyIndexes.entries) {
      final text = obj[entry.key];
      if (text is String) {
        entry.value.remove(text, key);
      }
    }
  }
}
