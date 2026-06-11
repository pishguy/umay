import 'relation_join_plan.dart';

class RelationJoinPlanner {
  RelationJoinPlanner();

  RelationJoinPlan plan({
    required String relationName,
    required String parentKey,
    required String childKey,
    required int parentCount,
    required int childCount,
    required bool many,
  }) {
    bool useHash = false;

    if (parentCount > 100 && childCount > 100) {
      useHash = true;
    }

    return RelationJoinPlan(
      relationName: relationName,
      parentKey: parentKey,
      childKey: childKey,
      many: many,
      useHashJoin: useHash,
    );
  }
}
