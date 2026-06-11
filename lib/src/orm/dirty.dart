mixin DirtyChecking {
  Map<String, dynamic> get dirtyAttributes;
  Map<String, dynamic> get dirtyOriginal;

  Map<String, dynamic> getDirty() {
    final dirty = <String, dynamic>{};
    dirtyAttributes.forEach((k, v) {
      if (dirtyOriginal[k] != v) dirty[k] = v;
    });
    return dirty;
  }

  bool isDirty() => getDirty().isNotEmpty;

  void syncOriginal() {
    dirtyOriginal
      ..clear()
      ..addAll(dirtyAttributes);
  }
}