import '../../umay_db.dart';

abstract class Relation<Parent, Related> {
  final UmayBox parentBox;
  final UmayBox relatedBox;

  Relation(this.parentBox, this.relatedBox);

  Future<List<Related>> loadMany(List<Parent> parents);

  Future<List<Related>> loadOne(Parent parent);
}
