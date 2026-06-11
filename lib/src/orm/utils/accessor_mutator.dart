/// تبدیل snake_case به StudlyCase
String studly(String value) {
  return value
      .split('_')
      .map((e) => e.isEmpty ? '' : e[0].toUpperCase() + e.substring(1))
      .join();
}

/// accessor برای [key] از [obj.accessors] برمی‌گردونه، یا null.
///
/// مدل باید override کنه:
/// ```dart
/// @override
/// Map<String, dynamic Function(dynamic)> get accessors => {
///   'full_name': (_) => '$firstName $lastName',
/// };
/// ```
dynamic Function(dynamic)? accessorFor(dynamic obj, String key) {
  try {
    final map = (obj as dynamic).accessors
    as Map<String, dynamic Function(dynamic)>;
    return map[key];
  } catch (_) {
    return null;
  }
}

/// mutator برای [key] از [obj.mutators] برمی‌گردونه، یا null.
///
/// مدل باید override کنه:
/// ```dart
/// @override
/// Map<String, dynamic Function(dynamic)> get mutators => {
///   'email': (v) => v.toString().toLowerCase(),
/// };
/// ```
dynamic Function(dynamic)? mutatorFor(dynamic obj, String key) {
  try {
    final map = (obj as dynamic).mutators
    as Map<String, dynamic Function(dynamic)>;
    return map[key];
  } catch (_) {
    return null;
  }
}