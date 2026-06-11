class IndexKey implements Comparable<IndexKey> {

  final Comparable value;

  IndexKey(this.value);

  @override
  int compareTo(IndexKey other) {
    return value.compareTo(other.value);
  }

  @override
  bool operator ==(Object other) {
    return other is IndexKey && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}
