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

class UmayCollection {
  final String? name;
  const UmayCollection([this.name]);
}

class UmayField {
  final bool index;
  final bool unique;
  final bool fuzzy;

  const UmayField({
    this.index = false,
    this.unique = false,
    this.fuzzy = false,
  });
}

/// تا با کلاس runtime در src/relations/has_many.dart conflict نداشته باشه.
///
/// این annotation فقط برای code generator هست.
/// در runtime از HasMany<Parent, Related> در src/relations/ استفاده کن.
class RelHasMany {
  final Type model;
  final String foreignKey;

  const RelHasMany(
      this.model, {
        required this.foreignKey,
      });
}

class RelBelongsTo {
  final Type model;
  final String foreignKey;

  const RelBelongsTo(
      this.model, {
        required this.foreignKey,
      });
}

/// Annotation برای ManyToMany
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