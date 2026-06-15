import 'dart:convert';

import '../../umay_db.dart';
import '../query/query_builder.dart';
import 'helpers.dart';
import 'model_event_dispatcher.dart';

/// Base ORM model with attribute management, dirty checking, serialization,
/// and static query/find/create methods backed by [UmayBox].
abstract class UmayModel {
  /// The model's primary key value.
  dynamic id;

  static final Map<Type, UmayBox> _boxes = {};
  static final Map<Type, Function> _factories = {};

  /// Global event dispatcher for model lifecycle events.
  static final ModelEventDispatcher events = ModelEventDispatcher();

  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic> _original = {};

  final Map<String, dynamic> _relations = {};
  final Map<String, int> _counts = {};

  /// Map of accessor names to their accessor functions.
  /// Accessors transform attribute values on read.
  Map<String, dynamic Function(dynamic)> get accessors => {};

  /// Map of mutator names to their mutator functions.
  /// Mutators transform attribute values on write.
  Map<String, dynamic Function(dynamic)> get mutators => {};

  /// Attribute keys to exclude from serialization.
  List<String> get hidden => [];

  /// Whitelist of attribute keys to include in serialization.
  /// If non-empty, only these keys are serialized.
  List<String> get visible => [];

  /// Virtual attribute keys appended during serialization.
  List<String> get appends => [];

  /// Attribute keys that are mass-assignable.
  List<String> get fillable => [];

  /// Attribute keys that are guarded from mass-assignment.
  /// Defaults to `['*']` which blocks all keys not in [fillable].
  List<String> get guarded => ['*'];

  /// Attribute type cast map (e.g. `{'age': 'int'}`).
  Map<String, String> get casts => {};

  // -----------------------------------------------
  // Registration
  // -----------------------------------------------
  /// Register a model type with a factory and a box.
  /// If the model implements [IndexableModel] its indexes are created automatically.
  static void register<T extends UmayModel>(T Function() creator, {required UmayBox box}) {
    _factories[T] = creator;
    _boxes[T] = box;

    final model = creator();
    if (model is IndexableModel) {
      final indexable = model as IndexableModel;
      print('🔍 REGISTER: indexed=${indexable.indexed} fuzzyIndexed=${indexable.fuzzyIndexed}');
      for (final field in indexable.indexed) {
        box.indexManager.createIndex(field);
      }
      for (final field in indexable.fuzzyIndexed) {
        box.indexManager.createFuzzyIndex(field);
      }
    }
  }

  /// Create a model instance of [type] using the registered factory.
  /// Returns `null` if [type] has not been registered.
  static UmayModel? createModel(Type type) {
    final factory = _factories[type];
    if (factory == null) return null;
    return factory();
  }

  /// Create a model from a map of attributes, optionally setting its [id].
  static T fromMap<T extends UmayModel>(Map<String, dynamic> data, {dynamic id}) {
    final model = _createModel<T>();
    model.id = id;
    model.hydrate(data);
    return model;
  }

  static T _createModel<T extends UmayModel>() {
    final creator = _factories[T];
    if (creator == null) {
      throw Exception(
        'Model factory for $T not registered. '
        'Call UmayModel.register<$T>(...) first.',
      );
    }
    return creator() as T;
  }

  static UmayBox _boxFor<T extends UmayModel>() {
    final b = _boxes[T];
    if (b == null) {
      throw Exception(
        'No box registered for $T. '
        'Call UmayModel.register<$T>(...) first.',
      );
    }
    return b;
  }

  // -----------------------------------------------
  // Accessors / Mutators / Casting
  // -----------------------------------------------
  /// Get an attribute by [key], applying casts and accessors.
  dynamic getAttribute(String key) {
    var value = _attributes[key];
    value = _castAttribute(key, value);

    final accessor = accessorFor(this, key);
    if (accessor != null) return accessor(value);

    return value;
  }

  /// Set an attribute by [key], applying mutators and guarding checks.
  void setAttribute(String key, dynamic value) {
    if (!_isFillable(key)) return;

    final mutator = mutatorFor(this, key);
    if (mutator != null) value = mutator(value);

    _attributes[key] = value;
  }

  bool _isFillable(String key) {
    if (guarded.contains('*') && !fillable.contains(key)) return false;
    if (guarded.contains(key)) return false;
    return true;
  }

  dynamic _castAttribute(String key, dynamic value) {
    final type = casts[key];
    if (type == null) return value;

    switch (type) {
      case 'int':
        return value is int ? value : int.tryParse('$value');
      case 'double':
        return value is double ? value : double.tryParse('$value');
      case 'bool':
        if (value is bool) return value;
        if (value == 1) return true;
        if (value == 0) return false;
        return value == 'true';
      case 'string':
        return value?.toString();
      case 'datetime':
        return value is DateTime ? value : DateTime.parse('$value');
      case 'json':
        return value is Map ? value : jsonDecode('$value');
      default:
        return value;
    }
  }

  // -----------------------------------------------
  // Fill / Hydrate
  // -----------------------------------------------
  /// Mass-assign attributes from [data], respecting fillable/guarded rules.
  void fill(Map<String, dynamic> data) {
    data.forEach((k, v) {
      if (_isFillable(k)) setAttribute(k, v);
    });
  }

  /// Mass-assign attributes from [data] without respecting fillable/guarded rules.
  void forceFill(Map<String, dynamic> data) {
    _attributes.addAll(data);
  }

  /// Replace all attributes with [data] and sync original values.
  void hydrate(Map<String, dynamic> data) {
    _attributes
      ..clear()
      ..addAll(data);
    syncOriginal();
  }

  /// Attach a related model (or list of models) under [name].
  void setRelation(String name, dynamic value) {
    _relations[name] = value;
  }

  /// Retrieve a previously set relation by [name].
  dynamic getRelation(String name) => _relations[name];

  void setCount(String name, int count) {
    _counts[name] = count;
  }

  int? getCount(String name) => _counts[name];

  // -----------------------------------------------
  // Serialization
  // -----------------------------------------------
  /// Serialize the model to a map, respecting [hidden], [visible], and [appends].
  Map<String, dynamic> toMap() {
    final out = <String, dynamic>{};

    if (id != null) out['id'] = id;

    _attributes.forEach((k, v) {
      if (hidden.contains(k)) return;
      if (visible.isNotEmpty && !visible.contains(k)) return;
      out[k] = getAttribute(k);
    });

    for (final append in appends) {
      out[append] = getAttribute(append);
    }

    // Include counts
    _counts.forEach((name, count) {
      out['${name}_count'] = count;
    });

    return out;
  }

  /// Alias for [toMap]; provided for JSON serialization consistency.
  Map<String, dynamic> toJson() => toMap();

  // -----------------------------------------------
  // Dirty Checking
  // -----------------------------------------------
  /// Check whether the model (or a specific [key]) has unsaved changes.
  bool isDirty([String? key]) {
    if (key != null) return _attributes[key] != _original[key];
    return getDirty().isNotEmpty;
  }

  /// Return a map of attributes whose values differ from their original state.
  Map<String, dynamic> getDirty() {
    final diff = <String, dynamic>{};
    _attributes.forEach((key, val) {
      if (_original[key] != val) diff[key] = val;
    });
    return diff;
  }

  /// Reset the original attribute snapshot to the current attribute values.
  void syncOriginal() {
    _original
      ..clear()
      ..addAll(_attributes);
  }

  // -----------------------------------------------
  // ORM API (Laravel-style)
  // -----------------------------------------------
  /// Find a model of type [T] by its primary key. Returns `null` if not found.
  static Future<T?> find<T extends UmayModel>(dynamic id) async {
    final box = _boxFor<T>();
    final raw = await box.get(id.toString());
    if (raw == null) return null;

    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'box.get() returned ${raw.runtimeType} for "$id"; '
        'expected Map<String, dynamic>.',
      );
    }

    final model = _createModel<T>();
    model.id = id;
    model.hydrate(raw);
    return model;
  }

  /// Create a query for type [T] filtered by [field] == [value].
  static QueryBuilder<T> where<T extends UmayModel>(String field, dynamic value) {
    final box = _boxFor<T>();
    final engine = QueryEngine(box, box.indexManager);
    return QueryBuilder<T>(engine).where(field, eq: value);
  }

  /// Start a fresh query builder for type [T].
  static QueryBuilder<T> query<T extends UmayModel>() {
    final box = _boxFor<T>();
    final engine = QueryEngine(box, box.indexManager);
    return QueryBuilder<T>(engine);
  }

  /// Create and persist a new model of type [T] with the given [data].
  static Future<T> create<T extends UmayModel>(Map<String, dynamic> data) async {
    final box = _boxFor<T>();
    final model = _createModel<T>();

    model.fill(data);
    model.id ??= generateId();

    await box.put(model.id.toString(), model.toMap());
    model.syncOriginal();
    return model;
  }

  /// Persist the current model state to the backing store.
  Future<void> save() async {
    final box = _boxes[runtimeType];
    if (box == null) {
      throw StateError(
        'No box registered for $runtimeType. '
        'Call UmayModel.register<$runtimeType>(...) first.',
      );
    }

    id ??= generateId();
    await box.put(id.toString(), toMap());
    syncOriginal();
  }

  /// Delete the model from the backing store. Does nothing if [id] is null.
  Future<void> delete() async {
    if (id == null) return;
    final box = _boxes[runtimeType];
    if (box == null) return;
    await box.delete(id.toString());
  }

  static int _idSeq = 0;

  /// Generate a unique string ID based on microsecond timestamp and a sequence counter.
  static String generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    _idSeq++;
    return '${ts.toRadixString(36)}_$_idSeq';
  }
}
