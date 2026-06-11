import 'relation.dart';

class EagerLoader {
  static Future<Map<P, List<R>>> load<P, R>(
      Relation<P, R> relation,
      List<P> parents,
      ) async {
    final map = <P, List<R>>{};

    for (final p in parents) {
      map[p] = [];
    }

    // Load children per parent individually
    for (final p in parents) {
      final children = await relation.loadOne(p);
      map[p] = children;
    }

    return map;
  }
}