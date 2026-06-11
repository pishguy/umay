enum ChangeType {
  put,
  delete,
}

class ChangeEvent {
  final String key;
  final ChangeType type;

  final dynamic oldValue;
  final dynamic newValue;

  ChangeEvent({
    required this.key,
    required this.type,
    this.oldValue,
    this.newValue,
  });
}
