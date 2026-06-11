import '../../index/compound_index.dart';
import '../filter.dart';
import '../secondary_index.dart';

/// انواع پلن‌های قابل برنامه‌ریزی توسط QueryPlanner.
/// شامل پلن‌های اندیسی معمول و همچنین پلن‌های Join.
enum QueryPlanType {
  fullScan,
  singleIndex,
  rangeIndex,
  compoundIndex,
  hashJoin,
  nestedLoopJoin,
}

/// ساختار عمومی برای نگهداری Plan انتخاب‌شده.
/// حالا از Hash Join هم پشتیبانی می‌کند.
class QueryPlan {
  final QueryPlanType type;

  // --- انواع Plan‌های ساده ---
  final SecondaryIndex? singleIndex;
  final CompoundIndex? compoundIndex;

  final Filter? singleFilter;
  final List<Filter>? compositeFilters;
  final dynamic min;
  final dynamic max;

  // --- برای Join ---
  final QueryPlan? left;
  final QueryPlan? right;
  final String? leftField;
  final String? rightField;

  QueryPlan._(
      this.type, {
        this.singleIndex,
        this.compoundIndex,
        this.singleFilter,
        this.compositeFilters,
        this.min,
        this.max,
        this.left,
        this.right,
        this.leftField,
        this.rightField,
      });

  /// Plan ساده Full Scan
  factory QueryPlan.full() {
    return QueryPlan._(QueryPlanType.fullScan);
  }

  /// Plan با تک ایندکس و فیلتری خاص
  factory QueryPlan.single(
      SecondaryIndex index,
      Filter filter,
      ) {
    return QueryPlan._(
      QueryPlanType.singleIndex,
      singleIndex: index,
      singleFilter: filter,
    );
  }

  /// Plan Range با محدودهٔ مشخص
  factory QueryPlan.range(
      SecondaryIndex index,
      dynamic min,
      dynamic max,
      ) {
    return QueryPlan._(
      QueryPlanType.rangeIndex,
      singleIndex: index,
      min: min,
      max: max,
    );
  }

  /// Plan ترکیبی - استفاده از CompoundIndex
  factory QueryPlan.composite(
      CompoundIndex index,
      List<Filter> filters,
      ) {
    return QueryPlan._(
      QueryPlanType.compoundIndex,
      compoundIndex: index,
      compositeFilters: filters,
    );
  }

  /// Plan Hash Join (استفاده از Hash Map برای اتصال)
  factory QueryPlan.hashJoin({
    required QueryPlan left,
    required QueryPlan right,
    required String leftField,
    required String rightField,
  }) {
    return QueryPlan._(
      QueryPlanType.hashJoin,
      left: left,
      right: right,
      leftField: leftField,
      rightField: rightField,
    );
  }

  /// Plan Nested Loop Join (روش کندتر ولی ساده‌تر)
  factory QueryPlan.nestedJoin({
    required QueryPlan left,
    required QueryPlan right,
    required String leftField,
    required String rightField,
  }) {
    return QueryPlan._(
      QueryPlanType.nestedLoopJoin,
      left: left,
      right: right,
      leftField: leftField,
      rightField: rightField,
    );
  }
}
