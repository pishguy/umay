class RelationResolver {
  static Future<Set<dynamic>> resolveNestedWhereHas(
      dynamic box,
      String relationPath,
      Function? callback,
      ) async {
    final parts = relationPath.split('.');
    final results = <dynamic>{};
    final parents = await box.all() as List;

    for (final parent in parents) {
      final ok = await _resolveRecursive(
        parent,
        box,
        parts,
        0,
        callback,
      );
      if (ok) results.add(parent);
    }

    return results;
  }

  static Future<bool> _resolveRecursive(
      dynamic parent,
      dynamic box,
      List<String> parts,
      int depth,
      Function? callback,
      ) async {
    final relationName = parts[depth];
    final relation = box.relations[relationName];
    if (relation == null) return false;

    final children = await relation.loadOne(parent) as List;
    if (children.isEmpty) return false;

    if (depth == parts.length - 1) {
      if (callback == null) return true;

      final q = relation.relatedBox.query();
      callback(q);
      final filtered = await q.find() as List;

      return filtered.any((f) => children.any((c) => _sameId(c, f)));
    }

    for (final child in children) {
      final ok = await _resolveRecursive(
        child,
        relation.relatedBox,
        parts,
        depth + 1,
        callback,
      );
      if (ok) return true;
    }

    return false;
  }

  static bool _sameId(dynamic a, dynamic b) {
    final idA = _extractId(a);
    final idB = _extractId(b);
    if (idA == null || idB == null) return false;
    return idA == idB;
  }

  static String? _extractId(dynamic obj) {
    if (obj == null) return null;

    // Map<String, dynamic>
    if (obj is Map) return obj['id']?.toString();

    // UmayModel یا هر object با .id
    try {
      return (obj as dynamic).id?.toString();
    } catch (_) {}

    // toJson() fallback
    try {
      final map = (obj as dynamic).toJson();
      if (map is Map) return map['id']?.toString();
    } catch (_) {}

    return null;
  }
}