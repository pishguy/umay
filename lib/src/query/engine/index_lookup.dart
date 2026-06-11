import '../../index/index_manager.dart';
import '../filter.dart';

class IndexLookup {
  static Set<String>? findCandidateKeys(List<Filter> filters,
      IndexManager indexManager,) {
    Set<String>? keys;

    for (final f in filters) {
      if (f.eq == null) continue;

      final index = indexManager.secondaryIndexes[f.field];

      if (index == null) continue;

      final found = index.get(f.eq);

      if (found == null) continue;

      final set = found.toSet();

      keys = keys == null ? set : keys.intersection(set);
    }

    return keys;
  }
}
