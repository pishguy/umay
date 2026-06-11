import 'dart:convert';
import 'dirty.dart';
import 'events.dart';

abstract class Model with DirtyChecking {
  final Map<String, dynamic> _attributes = {};
  final Map<String, dynamic> _original = {};

  @override
  Map<String, dynamic> get dirtyAttributes => _attributes;

  @override
  Map<String, dynamic> get dirtyOriginal => _original;

  List<String> get hidden => [];
  List<String> get visible => [];
  List<String> get fillable => [];
  List<String> get guarded => ['*'];
  List<String> get appends => [];
  Map<String, String> get casts => {};

  dynamic getAttribute(String key) {
    var value = _attributes[key];
    value = castAttribute(key, value);
    return value;
  }

  void setAttribute(String key, dynamic value) {
    if (!_isFillable(key)) return;
    _attributes[key] = value;
  }

  bool _isFillable(String key) {
    if (guarded.contains('*') && !fillable.contains(key)) return false;
    if (guarded.contains(key)) return false;
    return true;
  }

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

  void fill(Map<String, dynamic> data) {
    data.forEach(setAttribute);
  }

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

  String toJson() => jsonEncode(toMap());

  Future<void> save() async {
    ModelEvents.dispatch('saving', this);
    if (isDirty()) {
      await performUpdate(getDirty());
    }
    syncOriginal();
    ModelEvents.dispatch('saved', this);
  }

  Future<void> delete() async {
    ModelEvents.dispatch('deleting', this);
    await performDelete();
    ModelEvents.dispatch('deleted', this);
  }

  Future<void> performUpdate(Map data) async {}
  Future<void> performDelete() async {}
}