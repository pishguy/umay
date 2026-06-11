import 'version_chain.dart';
import 'versioned_record.dart';

class MVCCStorage<T> {
  final Map<String, VersionChain<T>> data = {};

  /// مقدار visible برای snapshot [txId] رو برمی‌گردونه.
  T? read(String key, int txId) {
    final chain = data[key];
    if (chain == null) return null;

    final v = chain.visible(txId);
    if (v == null || v.deleted) return null;

    return v.value;
  }

  /// Write uncommitted - تا commit صدا زده بشه قابل مشاهده نیست.
  void write(String key, T value, int txId) {
    final chain = data.putIfAbsent(key, () => VersionChain<T>());
    chain.add(VersionedRecord<T>(
      txId: txId,
      value: value,
      committed: false,
    ));
  }

  /// Soft delete uncommitted.
  void delete(String key, int txId) {
    final chain = data.putIfAbsent(key, () => VersionChain<T>());
    chain.add(VersionedRecord<T>(
      txId: txId,
      value: null,
      deleted: true,
      committed: false,
    ));
  }

  /// همه write های [txId] رو committed می‌کنه.
  void commit(int txId) {
    for (final chain in data.values) {
      chain.commitTransaction(txId);
    }
  }

  void rollback(int txId) {
    for (final chain in data.values) {
      chain.rollbackTransaction(txId);
    }
    // chain های خالی رو cleanup کن
    data.removeWhere((_, chain) => chain.isEmpty);
  }

  /// همه key های visible برای [txId].
  Iterable<String> keys(int txId) {
    return data.entries
        .where((e) {
      final v = e.value.visible(txId);
      return v != null && !v.deleted;
    })
        .map((e) => e.key);
  }
}