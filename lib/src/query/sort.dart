class Sorter {

  static void sortList<T>(
      List<T> list,
      String field,
      bool descending,
      dynamic Function(T obj, String field) getField,
      ) {

    list.sort((a, b) {

      final va = getField(a, field);
      final vb = getField(b, field);

      int cmp;

      if (va is Comparable && vb is Comparable) {
        cmp = va.compareTo(vb);
      } else {
        cmp = va.toString().compareTo(vb.toString());
      }

      return descending ? -cmp : cmp;
    });
  }
}
