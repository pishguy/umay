abstract class SoftDelete {

  DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  void markDeleted() {
    deletedAt = DateTime.now();
  }

  void restore() {
    deletedAt = null;
  }

}
