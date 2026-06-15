import 'dart:async';

import '../../../umay_db.dart';
import '../../reactive/query_watcher.dart';
import '../../relations/relation_query.dart';
import '../../relations/relation_resolver.dart';
import '../../utils/levenshtein.dart';
import '../../utils/text_normalizer.dart';
import '../pagination.dart';
import '../query_optimizer.dart';
import '../sort.dart';
import 'index_lookup.dart';
import 'query_cache.dart';

typedef _CompiledFilter = bool Function(Map<String, dynamic> row);

/// Core query execution engine with caching, indexing, and filtering.
class QueryEngine {
  /// The UmayBox this engine queries against.
  final UmayBox box;

  /// The index manager for fast lookups and fuzzy searches.
  final IndexManager indexManager;

  //instance-level cache
  final QueryCache _cache = QueryCache();

  QueryEngine(this.box, this.indexManager);

  /// Clears the query cache, forcing re-execution on next query.
  void invalidateAll() => _cache.clear();

  // -----------------------------------------------
  // ORM helpers
  // -----------------------------------------------
  /// Finds and returns a single record by its ID, or `null` if not found.
  Future<T?> find<T>(dynamic id) async {
    final obj = await box.get(id.toString());
    if (obj == null) return null;
    return _toModel<T>(obj, id: id);
  }

  /// Returns the first record matching the given filters, or `null` if none.
  Future<T?> first<T>({required List<Filter> filters}) async {
    final res = await execute<T>(
      filters: filters,
      includeDeleted: false,
      onlyDeleted: false,
      whereHasItems: const [],
      withCount: const {},
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }

  /// Returns all records matching the given filters with optional sorting and pagination.
  Future<List<T>> get<T>({
    required List<Filter> filters,
    String? sortField,
    bool descending = false,
    int? limit,
    int offset = 0,
  }) {
    return execute<T>(
      filters: filters,
      includeDeleted: false,
      onlyDeleted: false,
      whereHasItems: const [],
      withCount: const {},
      sortField: sortField,
      descending: descending,
      limit: limit,
      offset: offset,
    );
  }

  /// Persists a model to the store.
  Future<void> save(dynamic model) async {
    final id = _extractId(model);
    if (id == null) throw StateError('Cannot save: no id');
    await box.put(id, model);
    invalidateAll();
  }

  /// Deletes a record by ID.
  Future<void> delete(dynamic id) async {
    await box.delete(id.toString());
    invalidateAll();
  }

  /// Alias for [delete].
  Future<void> destroy(dynamic id) => delete(id);

  // -----------------------------------------------
  // Main execute
  // -----------------------------------------------
  /// Main execution method that compiles filters, applies indexes, and returns typed results.
  Future<List<T>> execute<T>({
    required List<Filter> filters,
    required bool includeDeleted,
    required bool onlyDeleted,
    required List whereHasItems,
    required Map<String, int> withCount,
    String? sortField,
    bool descending = false,
    int? limit,
    int offset = 0,
  }) async {
    //use instance methods
    final cacheKey = _cache.buildKey(
      filters,
      includeDeleted,
      onlyDeleted,
      whereHasItems,
      sortField,
      descending,
      limit,
      offset,
    );

    final cached = _cache.get(cacheKey);
    if (cached is List) return cached.cast<T>();

    // 1) Index lookup
    Set<String>? candidateKeys;

    final fastLookup =
    IndexLookup.findCandidateKeys(filters, indexManager);
    if (fastLookup != null) candidateKeys = fastLookup;

    // 2) Fuzzy
    for (final f in filters) {
      if (f.fuzzy != null) {
        final index = indexManager.fuzzyIndexes[f.field];
        if (index != null) {
          final keys = index.getCandidates(f.fuzzy!);
          if (keys.isNotEmpty) {
            candidateKeys = candidateKeys == null
                ? keys
                : candidateKeys.intersection(keys);
          }
        }
      }
    }

    // 3) Optimizer
    final plan = QueryOptimizer.chooseBestPlan(
      filters,
      indexManager.secondaryIndexes,
      indexManager.compositeIndexes,
    );

    if (plan != null) {
      if (plan.isComposite) {
        final query = <String, dynamic>{};
        for (final f in plan.compositeFilters!) {
          query[f.field] = f.eq;
        }
        final keys = plan.compositeIndex!.search(query).toSet();
        candidateKeys = candidateKeys == null
            ? keys
            : candidateKeys.intersection(keys);
      } else if (plan.isRange) {
        final index = plan.singleIndex!;
        Iterable<String>? keys;

        if (plan.min != null && plan.max != null) {
          keys = index.range(plan.min, plan.max);
        } else if (plan.min != null) {
          keys = index.rangeStart(plan.min);
        } else if (plan.max != null) {
          keys = index.rangeEnd(plan.max);
        }

        if (keys != null) {
          final set = keys.toSet();
          candidateKeys = candidateKeys == null
              ? set
              : candidateKeys.intersection(set);
        }
      } else {
        final keys = plan.singleIndex!.get(plan.singleFilter!.eq);
        if (keys != null) {
          final set = keys.toSet();
          candidateKeys = candidateKeys == null
              ? set
              : candidateKeys.intersection(set);
        }
      }
    }

    // 4) Fallback
    candidateKeys ??= box.indexKeys().toSet();
    if (whereHasItems.isNotEmpty) {
      final allowedKeys = <String>{};

      for (final item in whereHasItems) {
        String? relationPath;
        dynamic callback;

        if (item is Map) {
          relationPath = item['relation'] as String?;
          callback = item['callback'];
        } else if (item is RelationQuery) {
          relationPath = item.relation;
          callback = item.callback;
        }

        if (relationPath == null || relationPath.isEmpty) continue;

        final accepted = await RelationResolver.resolveNestedWhereHas(
          box,
          relationPath,
          callback,
        );

        for (final entity in accepted) {
          final id = _extractId(entity);
          if (id != null) allowedKeys.add(id);
        }
      }

      candidateKeys =
          candidateKeys.where((k) => allowedKeys.contains(k)).toSet();
    }

    // 6) Load objects
    final entries = <MapEntry<String, dynamic>>[];
    for (final key in candidateKeys) {
      final obj = await box.get(key);
      if (obj == null) continue;
      if (!_softDeleteCheck(obj, includeDeleted, onlyDeleted)) continue;
      entries.add(MapEntry(key, obj));
    }

    // 7) Compile + apply filters
    final compiledFilters = _compileFilters(filters);
    final filtered = <T>[];

    for (final entry in entries) {
      final map = _toMap(entry.value);
      if (map == null) continue;

      bool ok = true;
      for (final test in compiledFilters) {
        if (!test(map)) {
          ok = false;
          break;
        }
      }

      if (ok) {
        filtered.add(_toModel<T>(entry.value, id: entry.key));
      }
    }
    // 8) withCount
    if (withCount.isNotEmpty) {
      for (final obj in filtered) {
        for (final relationName in withCount.keys) {
          final relation = box.relations[relationName];
          if (relation == null) continue;

          final items = await relation.loadMany([obj]) as List;
          _attachCount(obj, relationName, items.length);
        }
      }
    }

    // 9) Sort
    if (sortField != null) {
      Sorter.sortList<T>(filtered, sortField, descending, _getField);
    }

    // 10) Pagination
    final paged = Pagination.apply(filtered, offset, limit);

    // 11) Cache
    _cache.put(cacheKey, List<T>.from(paged));

    return paged.cast<T>();
  }

  // -----------------------------------------------
  // Soft delete check
  // -----------------------------------------------
  bool _softDeleteCheck(
      dynamic obj,
      bool includeDeleted,
      bool onlyDeleted,
      ) {
    if (obj is SoftDelete) {
      if (onlyDeleted) return obj.isDeleted;
      if (!includeDeleted) return !obj.isDeleted;
      return true;
    }

    final map = _toMap(obj);
    if (map == null) return true;

    final deletedRaw = map['deleted_at'] ?? map['deletedAt'];
    final isDeleted =
        deletedRaw != null && deletedRaw.toString().isNotEmpty;

    if (onlyDeleted) return isDeleted;
    if (!includeDeleted) return !isDeleted;
    return true;
  }

  // -----------------------------------------------
  // Filter compilation
  // -----------------------------------------------
  List<_CompiledFilter> _compileFilters(List<Filter> filters) {
    final compiled = <_CompiledFilter>[];

    for (final f in filters) {
      if (f.eq != null) {
        compiled.add((row) => row[f.field] == f.eq);
      }

      if (f.gt != null) {
        compiled.add((row) {
          final cmp = _compareValues(row[f.field], f.gt);
          return cmp != null && cmp > 0;
        });
      }

      if (f.lt != null) {
        compiled.add((row) {
          final cmp = _compareValues(row[f.field], f.lt);
          return cmp != null && cmp < 0;
        });
      }

      if (f.gte != null) {
        compiled.add((row) {
          final cmp = _compareValues(row[f.field], f.gte);
          return cmp != null && cmp >= 0;
        });
      }

      if (f.lte != null) {
        compiled.add((row) {
          final cmp = _compareValues(row[f.field], f.lte);
          return cmp != null && cmp <= 0;
        });
      }

      if (f.contains != null) {
        final pattern = f.contains!;
        compiled.add((row) {
          final v = row[f.field];
          return v is String && v.contains(pattern);
        });
      }

      if (f.startsWith != null) {
        final pattern = f.startsWith!;
        compiled.add((row) {
          final v = row[f.field];
          return v is String && v.startsWith(pattern);
        });
      }

      if (f.endsWith != null) {
        final pattern = f.endsWith!;
        compiled.add((row) {
          final v = row[f.field];
          return v is String && v.endsWith(pattern);
        });
      }

      if (f.inValues != null) {
        compiled.add((row) => f.inValues!.contains(row[f.field]));
      }

      if (f.isNull == true) {
        compiled.add((row) => row[f.field] == null);
      }

      if (f.betweenStart != null || f.betweenEnd != null) {
        compiled.add((row) {
          final value = row[f.field];
          if (value == null) return false;

          if (f.betweenStart != null) {
            final cmp = _compareValues(value, f.betweenStart);
            if (cmp == null || cmp < 0) return false;
          }

          if (f.betweenEnd != null) {
            final cmp = _compareValues(value, f.betweenEnd);
            if (cmp == null || cmp > 0) return false;
          }

          return true;
        });
      }

      if (f.fuzzy != null) {
        final query = TextNormalizer.normalize(f.fuzzy!);
        final threshold = f.fuzzyThreshold ?? 0.4;

        compiled.add((row) {
          final v = row[f.field];
          if (v is! String) {
            return false;
          }

          final text = TextNormalizer.normalize(v);
          if (query.isEmpty) return true;

          // Sliding window: find the best-matching substring
          int minDist = query.length;
          final windowSize = query.length;
          for (int i = 0; i <= text.length - windowSize; i++) {
            final sub = text.substring(i, i + windowSize);
            final dist = Levenshtein.distance(query, sub);
            if (dist < minDist) minDist = dist;
          }
          // Also check shorter windows near boundaries
          if (text.length < windowSize) {
            final dist = Levenshtein.distance(query, text);
            if (dist < minDist) minDist = dist;
          }

          final score = 1 - (minDist / query.length);
          final pass = score >= threshold;
          return pass;
        });
      }
    }

    return compiled;
  }

  // -----------------------------------------------
  // Helpers
  // -----------------------------------------------
  int? _compareValues(dynamic a, dynamic b) {
    if (a == null || b == null) return null;

    if (a is num && b is num) return a.compareTo(b);

    if (a is DateTime && b is DateTime) return a.compareTo(b);

    if (a is DateTime && b is String) {
      return a.compareTo(DateTime.parse(b));
    }

    if (a is String && b is DateTime) {
      return DateTime.parse(a).compareTo(b);
    }

    if (a is Comparable && b is Comparable) {
      try {
        return a.compareTo(b);
      } catch (_) {}
    }

    return a.toString().compareTo(b.toString());
  }

  Map<String, dynamic>? _toMap(dynamic obj) {
    if (obj == null) return null;

    if (obj is Map<String, dynamic>) return obj;

    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }

    try {
      final json = (obj as dynamic).toJson();
      if (json is Map<String, dynamic>) return json;
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}

    try {
      final map = (obj as dynamic).toMap();
      if (map is Map<String, dynamic>) return map;
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}

    return null;
  }

  String? _extractId(dynamic obj) {
    final map = _toMap(obj);
    if (map != null && map['id'] != null) {
      return map['id'].toString();
    }

    try {
      final id = (obj as dynamic).id;
      if (id != null) return id.toString();
    } catch (_) {}

    return null;
  }

  void _attachCount(dynamic obj, String name, int count) {
    if (obj is Map<String, dynamic>) {
      obj['${name}_count'] = count;
      return;
    }

    try {
      (obj as dynamic).setCount(name, count);
    } catch (_) {}
  }

  dynamic _getField(dynamic obj, String field) {
    final map = _toMap(obj);
    return map?[field];
  }

  // -----------------------------------------------
  // Watch
  // -----------------------------------------------
  /// Returns a reactive stream of query results that updates automatically on data changes.
  Stream<List<T>> watch<T>({
    required List<Filter> filters,
    bool descending = false,
    String? sortField,
    bool includeDeleted = false,
    bool onlyDeleted = false,
  }) {
    final watcher = SmartQueryWatcher<T>(
      changes: box.watch(),
      filters: filters,
      getObject: (key) async {
        final obj = await box.get(key);
        if (obj == null) return null;
        return _toModel<T>(obj, id: key);
      },
      getAllKeys: () => box.indexKeys().toList(),
      initialRun: () async {
        return execute<T>(
          filters: filters,
          includeDeleted: includeDeleted,
          onlyDeleted: onlyDeleted,
          whereHasItems: const [],
          withCount: const {},
          sortField: sortField,
          descending: descending,
        );
      },
      sortField: sortField,
      sortDescending: descending,
      toMap: (obj) {
        final map = _toMap(obj);
        if (map == null) {
          throw StateError('Cannot convert watched object to Map');
        }
        return map;
      },
    );

    return watcher.stream;
  }

  T _toModel<T>(dynamic obj, {dynamic id}) {
    if (obj is T) return obj;
    if (obj is Map<String, dynamic>) {
      final instance = UmayModel.createModel(T);
      if (instance != null) {
        instance.id = id;
        instance.hydrate(obj);
        return instance as T;
      }
    }
    return obj as T;
  }
}