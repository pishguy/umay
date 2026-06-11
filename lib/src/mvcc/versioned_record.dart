class VersionedRecord<T> {
  final int txId;
  final T? value;
  final bool deleted;

  bool committed;

  VersionedRecord({
    required this.txId,
    required this.value,
    this.deleted = false,
    this.committed = false,
  });
}