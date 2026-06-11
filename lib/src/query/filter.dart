class Filter {
  final String field;

  final dynamic eq;
  final dynamic gt;
  final dynamic lt;
  final dynamic gte;
  final dynamic lte;

  final String? contains;
  final String? startsWith;
  final String? endsWith;

  final List? inValues;
  final bool? isNull;
  final dynamic betweenStart;
  final dynamic betweenEnd;

  // ✅ fuzzy search
  final String? fuzzy;
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
