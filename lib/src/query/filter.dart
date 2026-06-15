/// Represents a single filter condition for querying records.
class Filter {
  /// The name of the field to filter on.
  final String field;

  /// Equality value filter.
  final dynamic eq;

  /// Greater-than value filter.
  final dynamic gt;

  /// Less-than value filter.
  final dynamic lt;

  /// Greater-than-or-equal value filter.
  final dynamic gte;

  /// Less-than-or-equal value filter.
  final dynamic lte;

  /// Substring match filter.
  final String? contains;

  /// Prefix match filter.
  final String? startsWith;

  /// Suffix match filter.
  final String? endsWith;

  /// List-of-values inclusion filter.
  final List? inValues;

  /// Null check filter.
  final bool? isNull;

  /// Lower bound of a range filter.
  final dynamic betweenStart;

  /// Upper bound of a range filter.
  final dynamic betweenEnd;

  /// Fuzzy search query string.
  final String? fuzzy;

  /// Similarity threshold for fuzzy matching (0.0 to 1.0).
  final double? fuzzyThreshold;

  const Filter({
    required this.field,
    this.eq,
    this.gt,
    this.lt,
    this.gte,
    this.lte,
    this.contains,
    this.startsWith,
    this.endsWith,
    this.inValues,
    this.isNull,
    this.betweenStart,
    this.betweenEnd,
    this.fuzzy,
    this.fuzzyThreshold,
  });

  /// Whether this filter is a simple equality check.
  bool get isEquality => eq != null;

  @override
  String toString() {
    final buffer = StringBuffer();

    buffer.write(field);

    if (eq != null) buffer.write("=[$eq]");
    if (gt != null) buffer.write(">[$gt]");
    if (lt != null) buffer.write("<[$lt]");
    if (gte != null) buffer.write(">=[$gte]");
    if (lte != null) buffer.write("<=[$lte]");
    if (contains != null) buffer.write("~[$contains]");
    if (startsWith != null) buffer.write("^[$startsWith]");
    if (endsWith != null) buffer.write("\$[$endsWith]");

    if (inValues != null) buffer.write(" IN[$inValues]");
    if (isNull == true) buffer.write(" ISNULL");

    if (betweenStart != null || betweenEnd != null) {
      buffer.write(" BETWEEN[$betweenStart,$betweenEnd]");
    }

    if (fuzzy != null) {
      buffer.write(" FUZZY[$fuzzy]");
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is Filter &&
        field == other.field &&
        eq == other.eq &&
        gt == other.gt &&
        lt == other.lt &&
        gte == other.gte &&
        lte == other.lte &&
        contains == other.contains &&
        startsWith == other.startsWith &&
        endsWith == other.endsWith &&
        inValues == other.inValues &&
        isNull == other.isNull &&
        betweenStart == other.betweenStart &&
        betweenEnd == other.betweenEnd &&
        fuzzy == other.fuzzy &&
        fuzzyThreshold == other.fuzzyThreshold;
  }

  @override
  int get hashCode {
    return Object.hash(
      field,
      eq,
      gt,
      lt,
      gte,
      lte,
      contains,
      startsWith,
      endsWith,
      inValues,
      isNull,
      betweenStart,
      betweenEnd,
      fuzzy,
      fuzzyThreshold,
    );
  }
}
