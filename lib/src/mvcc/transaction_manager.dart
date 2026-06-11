import 'mvcc_storage.dart';
import 'transaction.dart';

class TransactionManager<T> {
  int _nextId = 1;
  final Set<int> active = {};
  final MVCCStorage<T> storage;

  TransactionManager(this.storage);

  Transaction begin() {
    final txId = _nextId++;
    active.add(txId);
    return Transaction(txId, txId);
  }

  void commit(Transaction tx) {
    storage.commit(tx.id);
    active.remove(tx.id);
  }

  void rollback(Transaction tx) {
    storage.rollback(tx.id);
    active.remove(tx.id);
  }

  bool isActive(int txId) => active.contains(txId);
}