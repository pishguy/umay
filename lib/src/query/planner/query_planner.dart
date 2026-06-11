import '../filter.dart';
import '../../index/index_manager.dart';
import 'query_plan.dart';

class QueryPlanner {

  static QueryPlan build(
      List<Filter> filters,
      IndexManager indexManager, {
        QueryPlan? rightPlan,
        String? leftField,
        String? rightField,
      }) {

    for (final cIndex in indexManager.compositeIndexes) {

      final used = <Filter>[];

      for (final field in cIndex.fields) {

        final f = filters.where((x) => x.field == field).firstOrNull;

        if (f == null || f.eq == null) {
          used.clear();
          break;
        }

        used.add(f);
      }

      if (used.length == cIndex.fields.length) {

        final base = QueryPlan.composite(cIndex, used);

        if (rightPlan != null && leftField != null && rightField != null) {

          return QueryPlan.hashJoin(
            left: base,
            right: rightPlan,
            leftField: leftField,
            rightField: rightField,
          );
        }

        return base;
      }
    }

    for (final f in filters) {

      final idx = indexManager.secondaryIndexes[f.field];

      if (idx != null && f.eq != null) {

        final base = QueryPlan.single(idx, f);

        if (rightPlan != null && leftField != null && rightField != null) {

          return QueryPlan.hashJoin(
            left: base,
            right: rightPlan,
            leftField: leftField,
            rightField: rightField,
          );
        }

        return base;
      }
    }

    for (final f in filters) {

      final idx = indexManager.secondaryIndexes[f.field];

      if (idx == null) continue;

      if (f.gt != null || f.gte != null || f.lt != null || f.lte != null) {

        final min = f.gt ?? f.gte;
        final max = f.lt ?? f.lte;

        final base = QueryPlan.range(idx, min, max);

        if (rightPlan != null && leftField != null && rightField != null) {

          return QueryPlan.hashJoin(
            left: base,
            right: rightPlan,
            leftField: leftField,
            rightField: rightField,
          );
        }

        return base;
      }
    }

    final full = QueryPlan.full();

    if (rightPlan != null && leftField != null && rightField != null) {

      return QueryPlan.nestedJoin(
        left: full,
        right: rightPlan,
        leftField: leftField,
        rightField: rightField,
      );
    }

    return full;
  }
}
