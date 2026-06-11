/// Instance-level query cache.
class QueryCache {
  static const int _maxEntries = 500;

  final Map<String, dynamic> _cache = {};

  String buildKey(
      List filters,
      bool includeDeleted,
      bool onlyDeleted,
      List whereHasItems,
      String? sortField,
      bool descending,
      int? limit,
      int offset,
      ) {
    final buffer = StringBuffer();

    for (final f in filters) {
      buffer.write('f:${f.toString()}|');
    }

    buffer.write('inc:$includeDeleted|');
    buffer.write('only:$onlyDeleted|');

    for (final item in whereHasItems) {
      buffer.write('wh:${_serializeWhereHas(item)}|');
    }

    buffer.write('sort:$sortField|');
    buffer.write('desc:$descending|');
    buffer.write('limit:$limit|');
    buffer.write('offset:$offset');

    return buffer.toString();
  }

  dynamic get(String key) => _cache[key];

  void put(String key, dynamic value) {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() => _cache.clear();

  String _serializeWhereHas(dynamic item) {
    if (item is Map) return item['relation']?.toString() ?? '';
    try {
      return (item as dynamic).relation?.toString() ?? '';
    } catch (_) {
      return '$item';
    }
  }
}