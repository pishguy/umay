import '../../umay_db.dart';
import '../query/secondary_index.dart';
import 'relation.dart';

class HasOne<Parent, Related> extends Relation<Parent, Related> {

  final String foreignKey;
  final dynamic Function(Parent) localKey;

  HasOne(
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
      return _scan(id);
    }

    final keys = index.get(id);

    if (keys == null || keys.isEmpty) {
      return [];
    }

    final obj = await relatedBox.get(keys.first);

    if (obj == null) return [];

    return [obj as Related];
  }

  Future<List<Related>> _scan(dynamic id) async {

    final all = await relatedBox.all();

    for (final item in all) {

      final fk = relatedBox.getField(item, foreignKey);

      if (fk == id) {
        return [item as Related];
      }
    }

    return [];
  }

  @override
  Future<List<Related>> loadMany(List<Parent> parents) async {

    final index = _index();

    if (index == null) return [];

    final ids = parents.map(localKey).toSet();

    final allKeys = <String>{};

    for (final id in ids) {

      final keys = index.get(id);

      if (keys != null) {
        allKeys.addAll(keys.cast<String>());
      }

    }

    final objects = await relatedBox.getMany(allKeys.toList());

    return objects.cast<Related>();
  }

}
