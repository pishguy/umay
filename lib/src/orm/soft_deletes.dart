import 'umay_model.dart';

/// Mixin که soft delete رو به UmayModel اضافه می‌کنه.
///
/// ```dart
/// class Comment extends UmayModel with SoftDeletes { ... }
/// ```
mixin SoftDeletes on UmayModel {
  DateTime? deletedAt;

  bool get trashed => deletedAt != null;

  // سازگاری با SoftDelete interface
  bool get isDeleted => trashed;

  @override
  Future<void> delete() async {
    deletedAt = DateTime.now();
    forceFill({'deleted_at': deletedAt!.toIso8601String()});
    await save();
  }

  /// رکورد رو بازگردانی می‌کنه.
  Future<void> restore() async {
    deletedAt = null;
    forceFill({'deleted_at': null});
    await save();
  }

  @override
  void hydrate(Map<String, dynamic> data) {
    super.hydrate(data);
    final raw = data['deleted_at'];
    if (raw != null && raw.toString().isNotEmpty) {
      deletedAt = DateTime.tryParse(raw.toString());
    } else {
      deletedAt = null;
    }
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['deleted_at'] = deletedAt?.toIso8601String();
    return map;
  }

  void markDeleted() {
    deletedAt = DateTime.now();
  }
}