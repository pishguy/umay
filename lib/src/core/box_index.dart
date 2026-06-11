// box_index.dart

/// In-memory index mapping keys to log file offsets.
///
/// This class is intentionally simple but provides:
/// - basic CRUD operations on the index
/// - ability to create from / export to a Map (for snapshots)
/// - some helpers that may be useful for metrics (e.g. live entry count).
class BoxIndex {
  /// Map from key -> offset in the log file.
  final Map<String, int> offsets = {};

  BoxIndex();

  BoxIndex.fromMap(Map<String, int> map) {
    offsets.addAll(map);
  }

  /// Add or update the offset for [key].
  void add(String key, int offset) {
    offsets[key] = offset;
  }

  /// Remove [key] from the index.
  void remove(String key) {
    offsets.remove(key);
  }

  /// Lookup operator: returns the offset for [key], or null.
  int? operator [](String key) => offsets[key];

  /// Whether the index contains [key].
  bool containsKey(String key) => offsets.containsKey(key);

  /// Number of entries in the index.
  int get length => offsets.length;

  /// Whether the index is empty.
  bool get isEmpty => offsets.isEmpty;

  /// Returns a shallow copy of the current index map.
  ///
  /// Useful for snapshots or compaction, to decouple from in-place mutations.
  Map<String, int> toMap() => Map<String, int>.from(offsets);

  /// Clears all entries in the index.
  void clear() => offsets.clear();

  /// Iterable over all entries.
  Iterable<MapEntry<String, int>> get entries => offsets.entries;
}
