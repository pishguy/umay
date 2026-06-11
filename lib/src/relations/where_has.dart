import 'relation_query.dart';
import '../query/linq_query_builder.dart';

extension WhereHasExtension on LinqQueryBuilder {
  LinqQueryBuilder whereHas(
      String relation,
      void Function(dynamic q)? callback,
      ) {
    whereHasQueries.add(RelationQuery(relation, callback));
    return this;
  }
}