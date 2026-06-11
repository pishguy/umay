import '../query/engine/hash_join.dart';
import 'relation_join_plan.dart';

class RelationJoinExecutor {

  RelationJoinExecutor();

  void execute({
    required RelationJoinPlan plan,
    required List<Map<String, dynamic>> parents,
    required List<Map<String, dynamic>> children,
  }) {

    if (parents.isEmpty || children.isEmpty) {
      return;
    }

    if (plan.useHashJoin) {
      _executeHash(plan, parents, children);
    } else {
      _executeIndexed(plan, parents, children);
    }
  }

  void _executeHash(
      RelationJoinPlan plan,
      List<Map<String, dynamic>> parents,
      List<Map<String, dynamic>> children,
      ) {

    final result = HashJoin.join(
      left: parents,
      right: children,
      leftKey: plan.parentKey,
      rightKey: plan.childKey,
    );

    for (final row in result) {

      final parent = row['left'];
      final child = row['right'];

      if (plan.many) {

        parent.putIfAbsent(plan.relationName, () => []);

        final list = parent[plan.relationName] as List;
        list.add(child);

      } else {

        parent[plan.relationName] = child;
      }
    }
  }

  void _executeIndexed(
      RelationJoinPlan plan,
      List<Map<String, dynamic>> parents,
      List<Map<String, dynamic>> children,
      ) {

    final index = <dynamic, List<Map<String, dynamic>>>{};

    for (final child in children) {

      final key = child[plan.childKey];

      index.putIfAbsent(key, () => []).add(child);
    }

    for (final parent in parents) {

      final key = parent[plan.parentKey];

      final matches = index[key];

      if (matches == null) {
        parent[plan.relationName] = plan.many ? [] : null;
        continue;
      }

      if (plan.many) {

        parent[plan.relationName] = List.from(matches);

      } else {

        parent[plan.relationName] = matches.first;
      }
    }
  }
}
