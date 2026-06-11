enum FilterOperator {
  eq,
  ne,
  gt,
  gte,
  lt,
  lte,
  between,
  inside,
  startsWith,
  endsWith,
  contains
}

abstract class QueryNode {}

class QueryFilter extends QueryNode {
  final String field;
  final FilterOperator operatorType;
  final dynamic value;
  final dynamic secondValue;

  QueryFilter(
      this.field,
      this.operatorType,
      this.value, [
        this.secondValue,
      ]);
}

class QueryAnd extends QueryNode {
  final List<QueryNode> children;

  QueryAnd(this.children);
}

class QueryOr extends QueryNode {
  final List<QueryNode> children;

  QueryOr(this.children);
}

class QueryNot extends QueryNode {
  final QueryNode child;

  QueryNot(this.child);
}

class QueryOrder {
  final String field;
  final bool descending;

  QueryOrder(this.field, {this.descending = false});
}

class QueryLimit {
  final int limit;

  QueryLimit(this.limit);
}

class QueryOffset {
  final int offset;

  QueryOffset(this.offset);
}

class RelationFilter extends QueryNode {
  final String relation;
  final QueryNode condition;

  RelationFilter(this.relation, this.condition);
}

class NestedRelationFilter extends QueryNode {
  final List<String> path;
  final QueryNode condition;

  NestedRelationFilter(this.path, this.condition);
}
