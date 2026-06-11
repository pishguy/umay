import '../../umay_db.dart';

class RelationLoader {
  /// Load nested dot-notation relations, e.g. "posts.comments".
  static Future<void> load(
      UmayBox box,
      List parents,
      List<String> relations,
      ) async {
    for (final relationPath in relations) {
      final parts = relationPath.split('.');
      await _loadLevel(box, parents, parts, 0);
    }
  }

  static Future<void> _loadLevel(
      UmayBox box,
      List parents,
      List<String> parts,
      int depth,
      ) async {
    if (parents.isEmpty) return;

    final relationName = parts[depth];
    final relation = box.relations[relationName];
    if (relation == null) return;

    final allChildren = <dynamic>[];

    for (final parent in parents) {
      final children = await relation.loadOne(parent) as List;
      allChildren.addAll(children);

      try {
        (parent as dynamic).setRelation(relationName, children);
      } catch (_) {
        // If model doesn't have setRelation, skip
      }
    }

    if (depth + 1 < parts.length) {
      await _loadLevel(
        relation.relatedBox,
        allChildren,
        parts,
        depth + 1,
      );
    }
  }
}