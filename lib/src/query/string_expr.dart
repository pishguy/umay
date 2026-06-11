import 'expressions.dart';

class StringExpr {
  final String field;

  StringExpr(this.field);

  FilterExpr contains(String value) {
    return FilterExpr(field, Op.contains, value);
  }

  FilterExpr startsWith(String value) {
    return FilterExpr(field, Op.startsWith, value);
  }

  FilterExpr endsWith(String value) {
    return FilterExpr(field, Op.endsWith, value);
  }
}
