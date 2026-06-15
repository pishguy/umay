import 'dart:convert';
import 'dirty.dart';
import 'events.dart';

/// Lightweight ORM model with attribute access, casting, dirty checking,
/// serialization, and lifecycle events.
abstract class Model with DirtyChecking {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic> _original = {};

  @override
  Map<String, dynamic> get dirtyAttributes => _attributes;

  @override
  Map<String, dynamic> get dirtyOriginal => _original;

  /// Attribute keys to exclude from serialization.
  List<String> get hidden => [];

  /// Whitelist of attribute keys to include in serialization.
  List<String> get visible => [];

  /// Attribute keys that are mass-assignable.
  List<String> get fillable => [];

  /// Attribute keys guarded from mass-assignment. Defaults to `['*']`.
  List<String> get guarded => ['*'];

  /// Virtual attribute keys appended during serialization.
  List<String> get appends => [];

  /// Attribute type cast map (e.g. `{'age': 'int'}`).
  Map<String, String> get casts => {};

  /// Get an attribute by [key], applying casts.
  dynamic getAttribute(String key) {
    var value = _attributes[key];
    value = castAttribute(key, value);
    return value;
  }

  /// Set an attribute by [key], respecting fillable/guarded rules.
  void setAttribute(String key, dynamic value) {
    if (!_isFillable(key)) return;
    _attributes[key] = value;
  }

  bool _isFillable(String key) {
    if (guarded.contains('*') && !fillable.contains(key)) return false;
    if (guarded.contains(key)) return false;
    return true;
  }

  /// Cast [value] for the given [key] according to the [casts] map.
  dynamic castAttribute(String key, dynamic value) {
    final type = casts[key];
    if (type == null) return value;

    switch (type) {
      case 'int':
        return value is int ? value : int.tryParse('$value');
      case 'bool':
        return value == true || value == 1;
      case 'double':
        return double.tryParse('$value');
      case 'string':
        return value?.toString();
      case 'datetime':
        if (value is DateTime) return value;
        return DateTime.tryParse('$value');
      case 'json':
        return value is Map ? value : jsonDecode('$value');
      default:
        return value;
    }
  }

  /// Mass-assign attributes from [data], respecting fillable/guarded rules.
  void fill(Map<String, dynamic> data) {
    data.forEach(setAttribute);
  }

  /// Serialize the model to a map, respecting [hidden], [visible], and [appends].
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};
    _attributes.forEach((k, v) {
      if (hidden.contains(k)) return;
      if (visible.isNotEmpty && !visible.contains(k)) return;
      result[k] = getAttribute(k);
    });
    for (final a in appends) {
      result[a] = getAttribute(a);
    }
    return result;
  }

  /// Serialize the model to a JSON-encoded string.
  String toJson() => jsonEncode(toMap());

  /// Persist dirty attributes by dispatching lifecycle events and calling [performUpdate].
  Future<void> save() async {
    ModelEvents.dispatch('saving', this);
    if (isDirty()) {
      await performUpdate(getDirty());
    }
    syncOriginal();
    ModelEvents.dispatch('saved', this);
  }

  /// Delete the model by dispatching lifecycle events and calling [performDelete].
  Future<void> delete() async {
    ModelEvents.dispatch('deleting', this);
    await performDelete();
    ModelEvents.dispatch('deleted', this);
  }

  /// Execute the persistence update. Override in subclasses for custom logic.
  Future<void> performUpdate(Map data) async {}

  /// Execute the deletion. Override in subclasses for custom logic.
  Future<void> performDelete() async {}
}