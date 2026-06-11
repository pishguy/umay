class QueryStats {

  static final Map<String,int> filterUsage = {};

  static void recordFilter(String field) {
    filterUsage[field] =
        (filterUsage[field] ?? 0) + 1;
  }

  static int usage(String field) {
    return filterUsage[field] ?? 0;
  }

}
