
import 'engine/query_engine.dart';
import 'filter.dart';

class QueryBuilder<T> {
  final QueryEngine engine;

  final List<Filter> _filters = [];
  String? _sortField;
  bool _descending = false;

  int? _limit;
  int _offset = 0;

  bool includeDeleted = false;
  bool onlyDeleted = false;

  final List _whereHas = [];
  final Map<String, int> _withCount = {};

  QueryBuilder(this.engine);

  QueryBuilder<T> where(
      String field, {
        dynamic eq,
        dynamic gt,
        dynamic gte,
        dynamic lt,
        dynamic lte,
        String? contains,
        String? startsWith,
        String? endsWith,
        List? inValues,
        bool? isNull,
        dynamic betweenStart,
        dynamic betweenEnd,
        String? fuzzy,
        double? fuzzyThreshold,
      }) {
    _filters.add(
      Filter(
        field: field,
        eq: eq,
        gt: gt,
        gte: gte,
        lt: lt,
        lte: lte,
        contains: contains,
        startsWith: startsWith,
        endsWith: endsWith,
        inValues: inValues,
        isNull: isNull,
        betweenStart: betweenStart,
        betweenEnd: betweenEnd,
        fuzzy: fuzzy,
        fuzzyThreshold: fuzzyThreshold,
      ),
    );
    return this;
  }

  QueryBuilder<T> whereHas(
      String relation,
      void Function(dynamic q)? callback,
      ) {
    _whereHas.add({
      'relation': relation,
      'callback': callback,
    });
    return this;
  }

  QueryBuilder<T> withCount(String relation) {
    _withCount[relation] = 1;
    return this;
  }

  QueryBuilder<T> withTrashed() {
    includeDeleted = true;
    return this;
  }

  QueryBuilder<T> onlyTrashed() {
    onlyDeleted = true;
    return this;
  }

  QueryBuilder<T> sortBy(String field, {bool desc = false}) {
    _sortField = field;
    _descending = desc;
    return this;
  }

  QueryBuilder<T> limit(int n) {
    _limit = n;
    return this;
  }

  QueryBuilder<T> offset(int n) {
    _offset = n;
    return this;
  }

  Future<List<T>> find() {
    return engine.execute<T>(
      filters: _filters,
      sortField: _sortField,
      descending: _descending,
      limit: _limit,
      offset: _offset,
      includeDeleted: includeDeleted,
      onlyDeleted: onlyDeleted,
      whereHasItems: _whereHas,
      withCount: _withCount,
    );
  }

  Future<List<T>> get() => find();

  Future<T?> first() async {
    limit(1);
    final list = await find();
    return list.isEmpty ? null : list.first;
  }

  Stream<List<T>> watch() {
    return engine.watch<T>(
      filters: _filters,
      sortField: _sortField,
      descending: _descending,
    );
  }
}