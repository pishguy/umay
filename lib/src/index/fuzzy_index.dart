class FuzzyIndex<K> {
  final Map<String, Set<K>> _trigrams = {};

  int debugTrigramCount() => _trigrams.length;
  Map<String, Set<K>> debugTrigrams() => Map.from(_trigrams);

  void add(String text, K key) {
    var grams = _generateTrigrams(text);
    for (var gram in grams) {
      _trigrams.putIfAbsent(gram, () => <K>{}).add(key);
    }
  }

  void remove(String text, K key) {
    var grams = _generateTrigrams(text);
    for (var gram in grams) {
      _trigrams[gram]?.remove(key);
      if (_trigrams[gram]?.isEmpty ?? false) {
        _trigrams.remove(gram);
      }
    }
  }

  Set<K> getCandidates(String query) {
    var queryGrams = _generateTrigrams(query);
    if (queryGrams.isEmpty) return {};

    Map<K, int> scores = {};
    for (var gram in queryGrams) {
      var matches = _trigrams[gram];
      if (matches != null) {
        for (var key in matches) {
          scores[key] = (scores[key] ?? 0) + 1;
        }
      }
    }

    // بازگرداندن کلیدهایی که حداقل در یک Trigram مشترک هستند
    return scores.keys.toSet();
  }

  List<String> _generateTrigrams(String text) {
    String t = text.toLowerCase();
    if (t.length < 3) return [t];
    List<String> grams = [];
    for (int i = 0; i <= t.length - 3; i++) {
      grams.add(t.substring(i, i + 3));
    }
    return grams;
  }

}
