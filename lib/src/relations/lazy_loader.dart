import 'relation.dart';

class LazyLoader {

  static Future<List<R>> load<P, R>(
      Relation<P, R> relation,
      P parent,
      ) {

    return relation.loadOne(parent);
  }
}
