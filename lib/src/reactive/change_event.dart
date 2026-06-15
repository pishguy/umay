/// Describes the type of data change.
enum ChangeType {
  /// A record was inserted or updated.
  put,

  /// A record was deleted.
  delete,
}

/// Represents a data change event with key, type, and value information.
class ChangeEvent {
  /// The key of the changed record.
  final String key;

  /// The type of change ([ChangeType.put] or [ChangeType.delete]).
  final ChangeType type;

  /// The previous value of the record, if available.
  final dynamic oldValue;

  /// The new value of the record, if available.
  final dynamic newValue;

  ChangeEvent({
    required this.key,
    required this.type,
    this.oldValue,
    this.newValue,
  });
}
