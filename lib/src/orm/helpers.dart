/// Convert snake_case => StudlyCase  (e.g. "first_name" → "FirstName")
String studly(String value) {
  return value
      .split('_')
      .map((e) => e.isEmpty ? '' : e[0].toUpperCase() + e.substring(1))
      .join();
}

// ---------------------------------------------------------------------------
// Accessor / Mutator support
//
// Dart has no runtime reflection in Flutter/AOT.
// The original helpers.dart tried to simulate reflection and always returned
// false from methodExists(), so no accessor/mutator was ever called.
//
// The correct pattern: each model overrides two Maps (accessors / mutators).
// UmayModel reads those maps directly.
// ---------------------------------------------------------------------------

/// Returns the accessor function for [key] from [obj.accessors], or null.
dynamic Function(dynamic)? accessorFor(dynamic obj, String key) {
  try {
    final map = (obj as dynamic).accessors
    as Map<String, dynamic Function(dynamic)>;
    return map[key];
  } catch (_) {
    return null;
  }
}

/// Returns the mutator function for [key] from [obj.mutators], or null.
dynamic Function(dynamic)? mutatorFor(dynamic obj, String key) {
  try {
    final map = (obj as dynamic).mutators
    as Map<String, dynamic Function(dynamic)>;
    return map[key];
  } catch (_) {
    return null;
  }
}