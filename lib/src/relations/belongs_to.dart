import '../../umay_db.dart';
import 'relation.dart';

class BelongsTo<Parent, Related> extends Relation<Parent, Related> {

  final dynamic Function(Parent) foreignKey;

  BelongsTo(
      UmayBox parentBox,
      UmayBox relatedBox,
      this.foreignKey,
      ) : super(parentBox, relatedBox);

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

  @override
  Future<List<Related>> loadOne(Parent parent) async {

    final id = foreignKey(parent);

    if (id == null) return [];

    final obj = await relatedBox.get(id.toString());

    if (obj == null) return [];

    return [obj as Related];
  }
}
