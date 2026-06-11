import '../query/linq_query_builder.dart';

extension WithCountExtension on LinqQueryBuilder {
  LinqQueryBuilder withCount(String relation) {
    withCountRelations[relation] = 1;

    return this;
  }
}
