import '../../umay_db.dart';
import '../relations/morph_to.dart';

mixin UmayModelRelations<ParentType> {
  /// Every model must provide its box
  UmayBox get box;

  BelongsTo<ParentType, Related>
  belongsTo<Related>(UmayBox relatedBox, dynamic Function(ParentType) fk) {
    return BelongsTo<ParentType, Related>(
      box,
      relatedBox,
      fk,
    );
  }

  HasMany<ParentType, Related> hasMany<Related>(
      UmayBox relatedBox,
      String foreignKey,
      dynamic Function(ParentType) localKey,
      ) {
    return HasMany<ParentType, Related>(
      box,
      relatedBox,
      foreignKey,
      localKey,
    );
  }

  HasOne<ParentType, Related> hasOne<Related>(
      UmayBox relatedBox,
      String foreignKey,
      dynamic Function(ParentType) localKey,
      ) {
    return HasOne<ParentType, Related>(
      box,
      relatedBox,
      foreignKey,
      localKey,
    );
  }

  MorphTo morphTo(String typeField, String idField) {
    return MorphTo(
      typeField: typeField,
      idField: idField,
    );
  }
}
