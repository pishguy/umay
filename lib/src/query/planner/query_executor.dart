import '../../../umay_db.dart';
import 'query_plan.dart';

class QueryExecutor {
  static Future<Set<String>> execute(UmayBox box, QueryPlan plan) async {
    switch (plan.type) {
      case QueryPlanType.compoundIndex:
        final query = <String, dynamic>{};

        for (final f in plan.compositeFilters!) {
          query[f.field] = f.eq;
        }

        final keys = plan.compoundIndex!.search(query);

        return keys.toSet();

      case QueryPlanType.singleIndex:
        final keys = plan.singleIndex!.get(plan.singleFilter!.eq);
        return keys?.toSet() ?? {};

      case QueryPlanType.rangeIndex:
        final index = plan.singleIndex!;
        Iterable<String>? keys;

        if (plan.min != null && plan.max != null) {
          keys = index.range(plan.min, plan.max);
        } else if (plan.min != null) {
          keys = index.rangeStart(plan.min);
        } else if (plan.max != null) {
          keys = index.rangeEnd(plan.max);
        }

        return keys?.toSet() ?? {};

      case QueryPlanType.fullScan:
        return box.indexKeys().toSet();

      case QueryPlanType.hashJoin:
        return await _executeHashJoin(box, plan);

      case QueryPlanType.nestedLoopJoin:
        return await _executeNestedJoin(box, plan);
    }
  }

  static Future<Set<String>> _executeHashJoin(UmayBox box, QueryPlan plan) async {
    final leftKeys = await execute(box, plan.left!);
    final rightKeys = await execute(box, plan.right!);

    final leftMap = <dynamic, List<String>>{};

    for (final key in leftKeys) {
      final rec = await box.get(key);
      if (rec == null) continue;

      final map = (rec is Map) ? rec : rec.toJson();
      final v = map[plan.leftField];

      if (v != null) {
        (leftMap[v] ??= []).add(key);
      }
    }

    final joined = <String>{};

    for (final key in rightKeys) {
      final rec = await box.get(key);
      if (rec == null) continue;

      final map = (rec is Map) ? rec : rec.toJson();
      final v = map[plan.rightField];

      if (v != null && leftMap.containsKey(v)) {
        joined.addAll(leftMap[v]!);
      }
    }

    return joined;
  }

  static Future<Set<String>> _executeNestedJoin(UmayBox box, QueryPlan plan) async {
    final leftKeys = await execute(box, plan.left!);
    final rightKeys = await execute(box, plan.right!);

    final joined = <String>{};

    for (final l in leftKeys) {
      final left = await box.get(l);
      if (left == null) continue;

      final lMap = (left is Map) ? left : left.toJson();
      final lVal = lMap[plan.leftField];

      for (final r in rightKeys) {
        final right = await box.get(r);
        if (right == null) continue;

        final rMap = (right is Map) ? right : right.toJson();
        final rVal = rMap[plan.rightField];

        if (rVal == lVal) {
          joined.add(l);
          break;
        }
      }
    }

    return joined;
  }
}
