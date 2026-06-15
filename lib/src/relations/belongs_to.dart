import 'relation.dart';

/// Defines a belongs-to relationship where the parent holds a foreign key to the related entity.
class BelongsTo<Parent, Related> extends Relation<Parent, Related> {

  /// A function that extracts the foreign key value from the parent.
  final dynamic Function(Parent) foreignKey;

  BelongsTo(
      super.parentBox,
      super.relatedBox,
      this.foreignKey,
      );

  /// Loads all related records for a list of parent entities.
  @override
  Future<List<Related>> loadMany(List<Parent> parents) async {

    final ids = parents
        .map(foreignKey)
        .where((e) => e != null)
        .toSet();

    final results = <Related>[];

    for (final id in ids) {

      final obj = await relatedBox.get(id.toString());

      if (obj != null) {
        results.add(obj as Related);
      }
    }

    return results;
  }

  /// Loads the related record for a single parent entity.
  @override
  Future<List<Related>> loadOne(Parent parent) async {

    final id = foreignKey(parent);

    if (id == null) return [];

    final obj = await relatedBox.get(id.toString());

    if (obj == null) return [];

    return [obj as Related];
  }
}
