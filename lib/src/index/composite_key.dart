class CompositeKey implements Comparable<CompositeKey> {
  final List<dynamic> parts;

  CompositeKey(this.parts);

  @override
  int compareTo(CompositeKey other) {
    final len = parts.length;

    for (int i = 0; i < len; i++) {
      final a = parts[i];
      final b = other.parts[i];

      if (a is Comparable && b is Comparable) {
        final c = a.compareTo(b);
        if (c != 0) return c;
      } else {
        // fallback
        final c = a.toString().compareTo(b.toString());
        if (c != 0) return c;
      }
    }

    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is CompositeKey && _equals(other.parts);

  bool _equals(List<dynamic> other) {
    if (other.length != parts.length) return false;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(parts);
}
