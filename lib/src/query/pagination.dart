class Pagination {

  static List<T> apply<T>(
      List<T> list,
      int offset,
      int? limit,
      ) {

    if (offset >= list.length) {
      return [];
    }

    final end = limit == null
        ? list.length
        : (offset + limit).clamp(0, list.length);

    return list.sublist(offset, end);
  }
}
