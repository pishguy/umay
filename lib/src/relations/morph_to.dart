import 'morph_map.dart';

class MorphTo {

  final String typeField;
  final String idField;

  MorphTo({
    required this.typeField,
    required this.idField,
  });

  Future<dynamic> load(dynamic obj) async {

    final type = obj.toJson()[typeField];
    final id = obj.toJson()[idField];

    final box = MorphMap.resolve(type);

    return box.get(id);
  }

}
