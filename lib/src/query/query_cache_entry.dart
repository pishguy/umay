class QueryCacheEntry {
  final List<Map<String, dynamic>> rows;
  final DateTime createdAt;

  QueryCacheEntry(this.rows) : createdAt = DateTime.now();
}

class QueryCache {
  final Map<String, QueryCacheEntry> _cache = {};

  /// Generate a deterministic cache key for a query
  String key({
    required String box,
    Map<String, dynamic>? where,
    List<String>? withRelations,
    int? limit,
    int? offset,
    String? orderBy,
  }) {
    final buffer = StringBuffer();
    buffer.write(box);

    if (where != null) {
      where.forEach((k, v) => buffer.write('|$k=$v'));
    }

    if (withRelations != null) {
      withRelations.sort();
      for (final rel in withRelations) {
        buffer.write('|rel:$rel');
      }
    }

    if (limit != null) buffer.write('|l:$limit');
    if (offset != null) buffer.write('|o:$offset');
    if (orderBy != null) buffer.write('|ord:$orderBy');

    return buffer.toString();
  }

  List<Map<String, dynamic>>? get(String key) => _cache[key]?.rows;

  void put(String key, List<Map<String, dynamic>> rows) {
    _cache[key] = QueryCacheEntry(rows);
  }

  void invalidateBox(String box) {
    final keys = _cache.keys.where((k) => k.startsWith(box)).toList();
    for (final k in keys) {
      _cache.remove(k);
    }
  }

  void clear() => _cache.clear();
}
