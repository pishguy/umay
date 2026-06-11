class MorphMany {

  final dynamic relatedBox;

  final String typeField;
  final String idField;

  final String morphName;

  MorphMany({
    required this.relatedBox,
    required this.typeField,
    required this.idField,
    required this.morphName,
  });

  Future<List> loadMany(dynamic parent) async {

    final q = relatedBox.query()
        .where(typeField, eq: morphName)
        .where(idField, eq: parent.id);

    return q.find();
  }

}
