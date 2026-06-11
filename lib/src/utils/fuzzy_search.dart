import 'dart:math';

import '../index/fuzzy_index.dart';
import 'levenshtein.dart';

class FuzzySearch<K> {
  final FuzzyIndex<K> _index = FuzzyIndex<K>();
  final Map<K, String> _sourceStrings = {};

  void index(K key, String value) {
    _index.add(value, key);
    _sourceStrings[key] = value;
  }

  void unindex(K key) {
    var val = _sourceStrings.remove(key);
    if (val != null) {
      _index.remove(val, key);
    }
  }

  List<SearchResult<K>> search(String query, {double threshold = 0.3}) {
    var candidates = _index.getCandidates(query);
    List<SearchResult<K>> results = [];

    for (var key in candidates) {
      String original = _sourceStrings[key]!;
      int dist = Levenshtein.distance(query.toLowerCase(), original.toLowerCase());

      // محاسبه امتیاز (۰ تا ۱)
      double similarity = 1 - (dist / max(query.length, original.length));

      if (similarity >= threshold) {
        results.add(SearchResult(key, original, similarity));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}

class SearchResult<K> {
  final K key;
  final String text;
  final double score;
  SearchResult(this.key, this.text, this.score);
}
