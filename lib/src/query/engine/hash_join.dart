class HashJoin {

  static List<Map<String,dynamic>> join({
    required List<Map<String,dynamic>> left,
    required List<Map<String,dynamic>> right,
    required String leftKey,
    required String rightKey,
  }) {

    final map = <dynamic,List<Map<String,dynamic>>>{};

    for (final r in right) {
      final key = r[rightKey];
      map.putIfAbsent(key, ()=>[]).add(r);
    }

    final result = <Map<String,dynamic>>[];

    for (final l in left) {

      final key = l[leftKey];

      final matches = map[key];

      if (matches == null) continue;

      for (final m in matches) {
        result.add({
          "left": l,
          "right": m
        });
      }
    }

    return result;
  }

}
