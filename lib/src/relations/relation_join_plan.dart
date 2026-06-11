class RelationJoinPlan {
  final String relationName;
  final String parentKey;
  final String childKey;
  final bool many;
  final bool useHashJoin;

  RelationJoinPlan({
    required this.relationName,
    required this.parentKey,
    required this.childKey,
    required this.many,
    required this.useHashJoin,
  });
}
