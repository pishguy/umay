import 'compound_index.dart';
import 'unique_index.dart';
import 'fuzzy_index.dart';
import '../query/secondary_index.dart';

/// Manages all index types (secondary, compound, unique, fuzzy, composite)
/// and coordinates index updates during put/delete operations.
class IndexManager {
  /// Maps field names to their secondary indexes.
  final Map<String, SecondaryIndex> secondaryIndexes = {};

  /// List of registered compound indexes.
  final List<CompoundIndex> compoundIndexes = [];

  /// List of registered unique indexes.
  final List<UniqueIndex> uniqueIndexes = [];

  /// Maps field names to their fuzzy (trigram) indexes.
  final Map<String, FuzzyIndex<String>> fuzzyIndexes = {};

  /// List of registered composite indexes (compound indexes used in query composition).
  final List<CompoundIndex> compositeIndexes = [];

  /// Returns true if any index type has been registered.
  bool get hasIndexes =>
      secondaryIndexes.isNotEmpty ||
      compoundIndexes.isNotEmpty ||
      uniqueIndexes.isNotEmpty ||
      fuzzyIndexes.isNotEmpty ||
      compositeIndexes.isNotEmpty;

  /// Creates a secondary index on the given field.
  void createIndex(String field) {
    secondaryIndexes[field] = SecondaryIndex(field);
  }

  /// Creates a compound index on the given list of fields.
  void createCompositeIndex(List<String> fields) {
    compoundIndexes.add(CompoundIndex(fields));
  }

  /// Creates a unique index on the given field.
  void createUniqueIndex<T extends Comparable<T>>(String field) {
    uniqueIndexes.add(UniqueIndex<T, String>(field));
  }

  /// Creates a fuzzy (trigram) index on the given field.
  void createFuzzyIndex(String field) {
    fuzzyIndexes[field] = FuzzyIndex<String>();
  }

  /// Updates all indexes when a record is inserted or updated.
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

  /// Removes a record from all indexes when it is deleted.
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
