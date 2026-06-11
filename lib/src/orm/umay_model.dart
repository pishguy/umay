import 'dart:convert';

import '../../umay_db.dart';
import '../query/engine/query_engine.dart';
import '../query/query_builder.dart';
import 'helpers.dart';
import 'indexable.dart';
import 'model_event_dispatcher.dart';

abstract class UmayModel {
  dynamic id;

  static final Map<Type, UmayBox> _boxes = {};
  static final Map<Type, Function> _factories = {};

  static final ModelEventDispatcher events = ModelEventDispatcher();

  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic> _original = {};

  final Map<String, dynamic> _relations = {};
  final Map<String, int> _counts = {};

  Map<String, dynamic Function(dynamic)> get accessors => {};

  Map<String, dynamic Function(dynamic)> get mutators => {};

  List<String> get hidden => [];

  List<String> get visible => [];

  List<String> get appends => [];

  List<String> get fillable => [];

  List<String> get guarded => ['*'];

  Map<String, String> get casts => {};

  // -----------------------------------------------
  // Registration
  // -----------------------------------------------
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

  static UmayModel? createModel(Type type) {
    final factory = _factories[type];
    if (factory == null) return null;
    return factory();
  }

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
  dynamic getAttribute(String key) {
    var value = _attributes[key];
    value = _castAttribute(key, value);

    final accessor = accessorFor(this, key);
    if (accessor != null) return accessor(value);

    return value;
  }

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
  void fill(Map<String, dynamic> data) {
    data.forEach((k, v) {
      if (_isFillable(k)) setAttribute(k, v);
    });
  }

  void forceFill(Map<String, dynamic> data) {
    _attributes.addAll(data);
  }

  void hydrate(Map<String, dynamic> data) {
    _attributes
      ..clear()
      ..addAll(data);
    syncOriginal();
  }

  void setRelation(String name, dynamic value) {
    _relations[name] = value;
  }

  dynamic getRelation(String name) => _relations[name];

  void setCount(String name, int count) {
    _counts[name] = count;
  }

  int? getCount(String name) => _counts[name];

  // -----------------------------------------------
  // Serialization
  // -----------------------------------------------
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

  Map<String, dynamic> toJson() => toMap();

  // -----------------------------------------------
  // Dirty Checking
  // -----------------------------------------------
  bool isDirty([String? key]) {
    if (key != null) return _attributes[key] != _original[key];
    return getDirty().isNotEmpty;
  }

  Map<String, dynamic> getDirty() {
    final diff = <String, dynamic>{};
    _attributes.forEach((key, val) {
      if (_original[key] != val) diff[key] = val;
    });
    return diff;
  }

  void syncOriginal() {
    _original
      ..clear()
      ..addAll(_attributes);
  }

  // -----------------------------------------------
  // ORM API (Laravel-style)
  // -----------------------------------------------
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

  static QueryBuilder<T> where<T extends UmayModel>(String field, dynamic value) {
    final box = _boxFor<T>();
    final engine = QueryEngine(box, box.indexManager);
    return QueryBuilder<T>(engine).where(field, eq: value);
  }

  static QueryBuilder<T> query<T extends UmayModel>() {
    final box = _boxFor<T>();
    final engine = QueryEngine(box, box.indexManager);
    return QueryBuilder<T>(engine);
  }

  static Future<T> create<T extends UmayModel>(Map<String, dynamic> data) async {
    final box = _boxFor<T>();
    final model = _createModel<T>();

    model.fill(data);
    model.id ??= generateId();

    await box.put(model.id.toString(), model.toMap());
    model.syncOriginal();
    return model;
  }

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

  Future<void> delete() async {
    if (id == null) return;
    final box = _boxes[runtimeType];
    if (box == null) return;
    await box.delete(id.toString());
  }

  static int _idSeq = 0;

  static String generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    _idSeq++;
    return '${ts.toRadixString(36)}_$_idSeq';
  }
}
