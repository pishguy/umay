import '../../umay_db.dart';
import '../relations/relation_loader.dart';
import '../relations/relation_query.dart';
import 'expressions.dart';

/// A paginated result set containing a slice of data with page metadata.
class PageResult<T> {
  /// The list of items for the current page.
  final List<T> data;

  /// The current page number (1-indexed).
  final int page;

  /// The number of items per page.
  final int perPage;

  /// The total number of items across all pages.
  final int total;

  PageResult({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
  });

  /// The total number of pages computed from [total] and [perPage].
  int get lastPage => (total / perPage).ceil();
}

/// A fluent query builder for constructing and executing queries against an [UmayBox].
class LinqQueryBuilder<T> {
  /// The UmayBox instance this query operates on.
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

  /// Includes soft-deleted records in the query results.
  LinqQueryBuilder<T> withTrashed() {
    _includeDeleted = true;
    return this;
  }

  /// Limits results to only soft-deleted records.
  LinqQueryBuilder<T> onlyTrashed() {
    _onlyDeleted = true;
    return this;
  }

  // -------------------- EAGER --------------------

  /// Eagerly loads the specified relation.
  LinqQueryBuilder<T> withRelation(String relation) {
    eagerRelations.add(relation);
    return this;
  }

  /// Alias for [withRelation].
  LinqQueryBuilder<T> include(String relation) =>
      withRelation(relation);

  /// Eagerly loads the count of related records for the given relation name.
  LinqQueryBuilder<T> withCount(String relation) {
    withCountRelations[relation] = 1;
    return this;
  }

  // -------------------- WHERE --------------------

  /// Adds a filter condition to the query.
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

  /// Adds an OR filter condition (not supported; throws [UnsupportedError]).
  LinqQueryBuilder<T> orWhere(Expr Function(dynamic x) predicate) {
    throw UnsupportedError(
      'orWhere is not yet supported. '
          'Use multiple queries and merge results manually.',
    );
  }

  /// Filters records where [field] is in the given list of values.
  LinqQueryBuilder<T> whereIn(String field, List values) {
    final expr = InExpr(field, values);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  /// Filters records where [field] is null.
  LinqQueryBuilder<T> whereNull(String field) {
    final expr = NullExpr(field);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  /// Filters records where [field] is between [a] and [b] (inclusive).
  LinqQueryBuilder<T> whereBetween(String field, dynamic a, dynamic b) {
    final expr = BetweenExpr(field, a, b);
    _expr = _expr == null
        ? expr
        : LogicalExpr(_expr!, Logic.and, expr);
    return this;
  }

  // -------------------- ORDER --------------------

  /// Sorts results in ascending order by the specified field.
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

  /// Sorts results in descending order by the specified field.
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

  /// Limits the number of results returned.
  LinqQueryBuilder<T> limit(int n) {
    _limit = n;
    return this;
  }

  /// Skips the specified number of results.
  LinqQueryBuilder<T> offset(int n) {
    _offset = n;
    return this;
  }

  // -------------------- EXECUTE --------------------

  /// Executes the query and returns the matching records.
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

  /// Executes the query and returns the first matching record, or `null` if none.
  Future<T?> first() async {
    _limit = 1;
    final r = await find();
    return r.isEmpty ? null : r.first;
  }

  /// Executes the query and returns the number of matching records.
  Future<int> count() async {
    final r = await find();
    return r.length;
  }

  /// Paginates the query results, returning a [PageResult] for the given page.
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

  /// Returns a broadcast stream that emits updated query results whenever data changes.
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