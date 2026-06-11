import 'string_expr.dart';

abstract class Expr {}

class FieldExpr extends Expr {
  final String field;

  FieldExpr(this.field);

  FilterExpr operator >(dynamic v) => FilterExpr(field, Op.gt, v);
  FilterExpr operator <(dynamic v) => FilterExpr(field, Op.lt, v);
  FilterExpr operator >=(dynamic v) => FilterExpr(field, Op.gte, v);
  FilterExpr operator <=(dynamic v) => FilterExpr(field, Op.lte, v);

  FilterExpr eq(dynamic v) => FilterExpr(field, Op.eq, v);

  FilterExpr notEq(dynamic v) => FilterExpr(field, Op.neq, v);

  FuzzyExpr fuzzy(dynamic v) => FuzzyExpr(field, v);

  StringExpr get string => StringExpr(field);

  @override
  bool operator ==(Object other) {
    if (other is! FieldExpr) return false;
    return field == other.field;
  }

  @override
  int get hashCode => field.hashCode;
}

class FilterExpr extends Expr {
  final String field;
  final Op op;
  final dynamic value;

  FilterExpr(this.field, this.op, this.value);

  LogicalExpr and(Expr other) => LogicalExpr(this, Logic.and, other);

  LogicalExpr or(Expr other) => LogicalExpr(this, Logic.or, other);
}

class LogicalExpr extends Expr {
  final Expr left;
  final Logic op;
  final Expr right;

  LogicalExpr(this.left, this.op, this.right);
}

class InExpr extends Expr {
  final String field;
  final List values;

  InExpr(this.field, this.values);
}

class NullExpr extends Expr {
  final String field;

  NullExpr(this.field);
}

class FuzzyExpr extends Expr {
  final String field;
  final dynamic value;
  final double threshold;

  FuzzyExpr(this.field, this.value, {this.threshold = 0.4});
}

class BetweenExpr extends Expr {
  final String field;
  final dynamic a;
  final dynamic b;

  BetweenExpr(this.field, this.a, this.b);
}

enum Logic { and, or }

enum Op {
  eq,
  neq,
  gt,
  lt,
  gte,
  lte,
  contains,
  startsWith,
  endsWith,
  fuzzy
}
