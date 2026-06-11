import '../index/compound_index.dart';
import 'filter.dart';
import 'secondary_index.dart';
import 'query_plan.dart';

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class QueryOptimizer {
  static QueryPlan? chooseBestPlan(
    List<Filter> filters,
    Map<String, SecondaryIndex> indexes,
    List<CompoundIndex> compositeIndexes,
  ) {
    // ------------------------------------------------
    // 1️⃣ Compound index
    // ------------------------------------------------

    QueryPlan? bestComposite;
    int bestCompositeSize = 1 << 62;

    for (final cIndex in compositeIndexes) {
      final query = <String, dynamic>{};
      final usedFilters = <Filter>[];

      bool matched = true;

      for (final field in cIndex.fields) {
        final f = filters.where((x) => x.field == field).firstOrNull;

        if (f == null || f.eq == null) {
          matched = false;
          break;
        }

        query[field] = f.eq;
        usedFilters.add(f);
      }

      if (!matched) continue;

      final keys = cIndex.search(query);
      final size = keys.length;

      if (size < bestCompositeSize) {
        bestCompositeSize = size;

        bestComposite = QueryPlan.composite(cIndex, usedFilters);
      }
    }

    if (bestComposite != null) {
      return bestComposite;
    }

    // ------------------------------------------------
    // 2️⃣ Single equality index
    // ------------------------------------------------

    Filter? best;
    SecondaryIndex? bestIndex;
    int bestSize = 1 << 62;

    for (final filter in filters) {
      final index = indexes[filter.field];
      if (index == null) continue;

      if (filter.eq != null) {
        final keys = index.get(filter.eq);
        final size = keys?.length ?? (1 << 60);

        if (size < bestSize) {
          bestSize = size;
          best = filter;
          bestIndex = index;
        }
      }
    }

    if (best != null && bestIndex != null) {
      return QueryPlan.single(bestIndex, best);
    }

    // ------------------------------------------------
    // 3️⃣ Range index
    // ------------------------------------------------

    dynamic min;
    dynamic max;
    SecondaryIndex? rangeIndex;

    for (final f in filters) {
      final idx = indexes[f.field];
      if (idx == null) continue;

      if (f.gt != null || f.gte != null) {
        min = f.gt ?? f.gte;
        rangeIndex = idx;
      }

      if (f.lt != null || f.lte != null) {
        max = f.lt ?? f.lte;
        rangeIndex = idx;
      }
    }

    if (rangeIndex != null) {
      return QueryPlan.range(rangeIndex, min, max);
    }

    // ------------------------------------------------
    // 4️⃣ Full scan
    // ------------------------------------------------

    return null;
  }
}
