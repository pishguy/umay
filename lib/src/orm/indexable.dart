/// Mixin for models whose fields should be indexed for fast lookup.
mixin IndexableModel {
  /// Field names to create exact-match indexes for.
  List<String> get indexed => [];

  /// Field names to create fuzzy (LIKE) indexes for.
  List<String> get fuzzyIndexed => [];
}
