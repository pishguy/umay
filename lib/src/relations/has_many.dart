import '../../umay_db.dart';
import '../query/secondary_index.dart';
import 'relation.dart';

class HasMany<Parent, Related> extends Relation<Parent, Related> {

  final String foreignKey;
  final dynamic Function(Parent) localKey;

  HasMany(
      UmayBox parentBox,
      UmayBox relatedBox,
      this.foreignKey,
      this.localKey,
      ) : super(parentBox, relatedBox);

  SecondaryIndex? _index() {
    return relatedBox.indexManager.secondaryIndexes[foreignKey];
  }

  @override
  Future<List<Related>> loadOne(Parent parent) async {

    final id = localKey(parent);

    final index = _index();

    if (index == null) {
      return _scanOne(id);
    }

    final keys = index.get(id);

    if (keys == null || keys.isEmpty) return [];

    final ids = keys.map((e) => e.toString()).toList();

    final objects = await relatedBox.getMany(ids);

    return objects.cast<Related>();
  }

  Future<List<Related>> _scanOne(dynamic id) async {

    final all = await relatedBox.all();

    final results = <Related>[];

    for (final item in all) {

      final fk = relatedBox.getField(item, foreignKey);

      if (fk == id) {
        results.add(item as Related);
      }

    }

    return results;
  }

  @override
  Future<List<Related>> loadMany(List<Parent> parents) async {

    final index = _index();

    if (index == null) {
      return _scanMany(parents);
    }

    final parentIds = parents.map(localKey).toSet();

    final allIds = <String>{};

    for (final id in parentIds) {

      final keys = index.get(id);

      if (keys == null) continue;

      for (final key in keys) {
        allIds.add(key.toString());
      }

    }

    final objects = await relatedBox.getMany(allIds.toList());

    return objects.cast<Related>();
  }

  Future<List<Related>> _scanMany(List<Parent> parents) async {

    final parentIds = parents.map(localKey).toSet();

    final all = await relatedBox.all();

    final results = <Related>[];

    for (final item in all) {

      final fk = relatedBox.getField(item, foreignKey);

      if (parentIds.contains(fk)) {
        results.add(item as Related);
      }

    }

    return results;
  }

}
