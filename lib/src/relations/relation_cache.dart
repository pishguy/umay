class RelationCache {

  final Map<String, Map<String, dynamic>> _cache = {};

  dynamic get(String relation, String parentId) {
    final map = _cache[relation];
    if (map == null) return null;
    return map[parentId];
  }

  void put(String relation, String parentId, dynamic value) {
    _cache.putIfAbsent(relation, () => {});
    _cache[relation]![parentId] = value;
  }

  void clear() {
    _cache.clear();
  }

}
