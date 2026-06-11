import 'expressions.dart';
import 'filter.dart';

class ExpressionConverter {
  static List<Filter> convert(Expr? expr) {
    if (expr == null) return [];

    if (expr is FilterExpr) {
      return [
        Filter(
          field: expr.field,
          eq: expr.op == Op.eq ? expr.value : null,
          gt: expr.op == Op.gt ? expr.value : null,
          lt: expr.op == Op.lt ? expr.value : null,
          gte: expr.op == Op.gte ? expr.value : null,
          lte: expr.op == Op.lte ? expr.value : null,
          contains: expr.op == Op.contains ? expr.value : null,
          startsWith: expr.op == Op.startsWith ? expr.value : null,
          endsWith: expr.op == Op.endsWith ? expr.value : null,
        )
      ];
    }

    if (expr is LogicalExpr) {
      final left = convert(expr.left);
      final right = convert(expr.right);

      return [...left, ...right];
    }

    throw Exception("Unsupported expression");
  }
}
