import '../index/compound_index.dart';
import 'secondary_index.dart';
import 'filter.dart';

class QueryPlan {

  final SecondaryIndex? singleIndex;
  final CompoundIndex? compositeIndex;

  final Filter? singleFilter;
  final List<Filter>? compositeFilters;

  final dynamic min;
  final dynamic max;
  final bool isRange;

  QueryPlan.single(this.singleIndex, this.singleFilter)
      : compositeIndex = null,
        compositeFilters = null,
        min = null,
        max = null,
        isRange = false;

  QueryPlan.composite(this.compositeIndex, this.compositeFilters)
      : singleIndex = null,
        singleFilter = null,
        min = null,
        max = null,
        isRange = false;

  QueryPlan.range(this.singleIndex, this.min, this.max)
      : singleFilter = null,
        compositeIndex = null,
        compositeFilters = null,
        isRange = true;

  bool get isComposite => compositeIndex != null;
}
