/// Mixin-like abstract class that adds soft-delete capability to a model.
abstract class SoftDelete {

  /// Timestamp indicating when the model was soft-deleted. `null` means active.
  DateTime? deletedAt;

  /// Whether the model has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Mark the model as deleted by setting [deletedAt] to now.
  void markDeleted() {
    deletedAt = DateTime.now();
  }

  /// Restore the model by clearing [deletedAt].
  void restore() {
    deletedAt = null;
  }

}
