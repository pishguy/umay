import '../../umay_db.dart';
import '../relations/relation_loader.dart';
import '../relations/relation_query.dart';
import 'expressions.dart';
import 'filter.dart';
import 'proxy_builder.dart';

class PageResult<T> {
  final List<T> data;
  final int page;
  final int perPage;
  final int total;

  PageResult({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
  });

  int get lastPage => (total / perPage).ceil();
}

class LinqQueryBuilder<T> {
  final UmayBox box;

  Expr? _expr;
  String? _sortField;
  bool _sortDescending = false;

  int? _limit;
  int _offset = 0;

  final List<RelationQuery> whereHasQueries = [];
  final Map<String, int> withCountRelations = {};
  final List<String> eagerRelations = [];

  bool _includeDeleted = false;
  bool _onlyDeleted = false;

  LinqQueryBuilder(this.box);

  // -------------------- SOFT DELETE --------------------

  LinqQueryBuilder<T> withTrashed() {
    _includeDeleted = true;
    return this;
  }

  LinqQueryBuilder<T> onlyTrashed() {
    _onlyDeleted = true;
    return this;
  }

  // -------------------- EAGER --------------------

  LinqQueryBuilder<T> withRelation(String relation) {
    eagerRelations.add(relation);
    return this;
  }

  LinqQueryBuilder<T> include(String relation) =>
      withRelation(relation);

  LinqQueryBuilder<T> withCount(String relation) {
    withCountRelations[relation] = 1;
    return this;
  }

  // -------------------- WHERE --------------------

  LinqQueryBuilder<T> where(Expr Function(dynamic x) predicate) {
    final proxy = ProxyBuilder<T>().build();
    final expr = predicate(proxy);

    if (_expr == null) {
      _expr = expr;
    } else {
      _expr = LogicalExpr(_expr!, Logic.and, expr);
    }

    return this;
  }

  //OR not truly supported in engine,
  //         throw clear error instead of silent wrong results
  LinqQueryBuilder<T> orWhere(Expr Function(dynamic x) predicate) {
    throw UnsupportedError(
      'orWhere is not yet supported. '
          'Use multiple queries and merge results manually.',
    );
  }

  LinqQueryBuilder<T> whereIn(String field, List values) {
    final expr = InExpr(field, values);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  LinqQueryBuilder<T> whereNull(String field) {
    final expr = NullExpr(field);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  LinqQueryBuilder<T> whereBetween(String field, dynamic a, dynamic b) {
    final expr = BetweenExpr(field, a, b);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  // -------------------- ORDER --------------------

  LinqQueryBuilder<T> orderBy(Expr Function(dynamic x) selector) {
    final proxy = ProxyBuilder<T>().build();
    final expr = selector(proxy);

    if (expr is FieldExpr) {
      _sortField = expr.field;
      _sortDescending = false;
    } else {
      throw Exception('orderBy requires field selector');
    }

    return this;
  }

  LinqQueryBuilder<T> orderByDesc(Expr Function(dynamic x) selector) {
    final proxy = ProxyBuilder<T>().build();
    final expr = selector(proxy);

    if (expr is FieldExpr) {
      _sortField = expr.field;
      _sortDescending = true;
    } else {
      throw Exception('orderByDesc requires field selector');
    }

    return this;
  }

  // -------------------- LIMIT --------------------

  LinqQueryBuilder<T> limit(int n) {
    _limit = n;
    return this;
  }

  LinqQueryBuilder<T> offset(int n) {
    _offset = n;
    return this;
  }

  // -------------------- EXECUTE --------------------

  Future<List<T>> find() async {
    final filters = _convertExpr(_expr);

    final results = await box.queryEngine.execute<T>(
      filters: filters,
      sortField: _sortField,
      descending: _sortDescending,
      limit: _limit,
      offset: _offset,
      includeDeleted: _includeDeleted,
      onlyDeleted: _onlyDeleted,
      whereHasItems: whereHasQueries,
      withCount: withCountRelations,
    );

    if (eagerRelations.isNotEmpty) {
      await RelationLoader.load(box, results, eagerRelations);
    }

    return results;
  }

  Future<T?> first() async {
    _limit = 1;
    final r = await find();
    return r.isEmpty ? null : r.first;
  }

  Future<int> count() async {
    final r = await find();
    return r.length;
  }

  Future<PageResult<T>> paginate(int page, int perPage) async {
    // Count without limit/offset
    final countBuilder = LinqQueryBuilder<T>(box);
    countBuilder._expr = _expr;
    countBuilder.whereHasQueries.addAll(whereHasQueries);
    final total = await countBuilder.count();

    // Fetch page
    final data = await limit(perPage)
        .offset((page - 1) * perPage)
        .find();

    return PageResult<T>(
      data: data,
      page: page,
      perPage: perPage,
      total: total,
    );
  }

  // -------------------- WATCH --------------------

  Stream<List<T>> watch() {
    final filters = _convertExpr(_expr);
    return box.queryEngine.watch<T>(
      filters: filters,
      sortField: _sortField,
      descending: _sortDescending,
      includeDeleted: _includeDeleted,
      onlyDeleted: _onlyDeleted,
    );
  }

  // -------------------- EXPR CONVERSION --------------------

  List<Filter> _convertExpr(Expr? expr) {
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
        ),
      ];
    }

    if (expr is LogicalExpr) {
      final left = _convertExpr(expr.left);
      final right = _convertExpr(expr.right);
      return [...left, ...right];
    }

    if (expr is InExpr) {
      return [Filter(field: expr.field, inValues: expr.values)];
    }

    if (expr is NullExpr) {
      return [Filter(field: expr.field, isNull: true)];
    }

    if (expr is FuzzyExpr) {
      return [
        Filter(
          field: expr.field,
          fuzzy: expr.value,
          fuzzyThreshold: expr.threshold,
        ),
      ];
    }

    if (expr is BetweenExpr) {
      return [
        Filter(
          field: expr.field,
          betweenStart: expr.a,
          betweenEnd: expr.b,
        ),
      ];
    }

    throw Exception('Unsupported expression type: ${expr.runtimeType}');
  }
}