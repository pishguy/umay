// =============================================================
// مسیر فایل: umay/src/annotations/umay_annotations.dart
//
// ❌ باگ اصلی:
//   کلاس‌های HasMany و BelongsTo در این فایل تعریف شده بودن.
//   این اسامی دقیقاً با کلاس‌های runtime در
//   src/relations/has_many.dart و src/relations/belongs_to.dart
//   یکسان بودن.
//
//   وقتی در main.dart هر دو import می‌شدن، Dart annotation ها رو
//   به جای relation class های واقعی می‌گرفت چون annotation ها
//   0 type parameter دارن ولی relation class ها 2 تا دارن.
//
//   نتیجه:
//     HasMany<Map, Map>(...) → خطا: 0 type params expected
//     HasMany.loadOne() → خطا: method not found
//
// ✅ راه‌حل:
//   annotation ها رو با پیشوند Rel rename کن تا conflict نباشه:
//     HasMany     → RelHasMany
//     BelongsTo   → RelBelongsTo
//
//   این annotation ها فقط برای code generator هستن و در runtime
//   هیچ کاری نمی‌کنن. تغییر اسم هیچ تأثیری روی عملکرد نداره.
// =============================================================

/// Annotation that marks a class as an Umay collection/entity.
class UmayCollection {
  /// Optional custom name for the collection. If null, the class name is used.
  final String? name;
  const UmayCollection([this.name]);
}

/// Annotation that marks a field for indexing or special handling.
class UmayField {
  /// Whether this field should be indexed for fast lookups.
  final bool index;

  /// Whether this field should have a unique constraint.
  final bool unique;

  /// Whether this field supports fuzzy text search.
  final bool fuzzy;

  const UmayField({
    this.index = false,
    this.unique = false,
    this.fuzzy = false,
  });
}

/// Annotation for code generation of a one-to-many relationship.
///
/// Use the runtime class `HasMany<Parent, Related>` from `src/relations/` for actual queries.
class RelHasMany {
  /// The type of the related model.
  final Type model;

  /// The foreign key field name on the related box.
  final String foreignKey;

  const RelHasMany(
      this.model, {
        required this.foreignKey,
      });
}

/// Annotation for code generation of a belongs-to relationship.
class RelBelongsTo {
  /// The type of the related model.
  final Type model;

  /// The foreign key field name.
  final String foreignKey;

  const RelBelongsTo(
      this.model, {
        required this.foreignKey,
      });
}

/// Annotation for code generation of a many-to-many relationship.
class RelManyToMany {
  final Type model;
  final String pivotTable;
  final String foreignKey;
  final String relatedKey;

  const RelManyToMany(
      this.model, {
        required this.pivotTable,
        required this.foreignKey,
        required this.relatedKey,
      });
}