import '../../umay_db.dart';
import 'relation.dart';

/// Defines a many-to-many relationship between two entity types via a pivot table.
class ManyToMany<Parent, Related> extends Relation<Parent, Related> {

  /// The pivot table managing the relationship.
  final PivotTable pivot;

  /// A function that extracts the parent's key value.
  final dynamic Function(Parent) parentKey;

  ManyToMany(
      super.parentBox,
      super.relatedBox,
      this.pivot,
      this.parentKey,
      );

  /// Loads all related records for a list of parent entities.
  @override
  Future<List<Related>> loadMany(List<Parent> parents) async {

    final allIds = <String>{};

    for (final parent in parents) {

      final key = parentKey(parent);

      final ids = pivot.getForward(key);

      if (ids == null) continue;

      for (final id in ids) {
        allIds.add(id.toString());
      }

    }

    final objects = await relatedBox.getMany(allIds.toList());

    return objects.cast<Related>();
  }

  /// Loads the related records for a single parent entity.
  @override
  Future<List<Related>> loadOne(Parent parent) async {

    final key = parentKey(parent);

    final ids = pivot.getForward(key);

    if (ids == null || ids.isEmpty) return [];

    final keyList = ids.map((e) => e.toString()).toList();

    final objects = await relatedBox.getMany(keyList);

    return objects.cast<Related>();
  }

}
