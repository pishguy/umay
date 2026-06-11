import '../../umay_db.dart';
import 'relation.dart';
import 'pivot_table.dart';

class ManyToMany<Parent, Related> extends Relation<Parent, Related> {

  final PivotTable pivot;
  final dynamic Function(Parent) parentKey;

  ManyToMany(
      UmayBox parentBox,
      UmayBox relatedBox,
      this.pivot,
      this.parentKey,
      ) : super(parentBox, relatedBox);

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
