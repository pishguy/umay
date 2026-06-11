import 'versioned_record.dart';

class VersionChain<T> {
  final List<VersionedRecord<T>> versions = [];

  void add(VersionedRecord<T> record) {
    versions.insert(0, record);
  }

  /// 1. تراکنش uncommitted write های خودش رو می‌بینه
  /// 2. بقیه فقط committed records می‌بینن
  /// 3. آخرین committed که txId <= snapshot
  VersionedRecord<T>? visible(int txId) {
    for (final v in versions) {
      // خود تراکنش uncommitted write های خودش رو می‌بینه
      if (v.txId == txId) return v;
      // بقیه فقط committed records قبل از snapshot
      if (v.committed && v.txId <= txId) return v;
    }
    return null;
  }

  /// همه version های [txId] رو committed علامت می‌زنه.
  void commitTransaction(int txId) {
    for (final v in versions) {
      if (v.txId == txId) v.committed = true;
    }
  }

  void rollbackTransaction(int txId) {
    versions.removeWhere((v) => v.txId == txId && !v.committed);
  }

  bool get isEmpty => versions.isEmpty;
}