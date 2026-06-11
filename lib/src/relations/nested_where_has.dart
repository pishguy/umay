import 'relation_path.dart';

class NestedWhereHas {
  static Future<Set<dynamic>> resolve(
      dynamic rootBox,
      String path,
      dynamic callback,
      ) async {
    final relationPath = RelationPath(path);

    List<dynamic> currentObjects = await rootBox.all() as List;
    dynamic currentBox = rootBox;

    for (final segment in relationPath.segments) {
      final relation = currentBox.relations[segment];
      if (relation == null) return {};

      final next = <dynamic>[];

      for (final parent in currentObjects) {
        final children = await relation.loadOne(parent) as List;
        next.addAll(children);
      }

      currentObjects = next;
      currentBox = relation.relatedBox;
    }

    if (callback != null) {
      final filtered = <dynamic>[];

      for (final item in currentObjects) {
        final q = currentBox.query();
        callback(q);
        final results = await q.find() as List;

        final itemId = _extractId(item);
        if (itemId != null &&
            results.any((r) => _extractId(r) == itemId)) {
          filtered.add(item);
        }
      }

      return filtered.toSet();
    }

    return currentObjects.toSet();
  }

  static String? _extractId(dynamic obj) {
    if (obj is Map) return obj['id']?.toString();
    try {
      return (obj as dynamic).id?.toString();
    } catch (_) {
      return null;
    }
  }
}