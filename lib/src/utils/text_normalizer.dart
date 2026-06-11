class TextNormalizer {
  static final _arabicChars = {
    'ي': 'ی',
    'ك': 'ک',
    'ؤ': 'و',
    'إ': 'ا',
    'أ': 'ا',
    'ۀ': 'ه',
  };

  static final _diacritics = RegExp(r'[\u064B-\u065F]');
  static final _tatweel = RegExp(r'ـ');
  static final _multiSpace = RegExp(r'\s+');

  static String normalize(String input) {
    var s = input;

    // arabic → persian
    _arabicChars.forEach((a, p) {
      s = s.replaceAll(a, p);
    });

    // remove diacritics
    s = s.replaceAll(_diacritics, '');

    // remove tatweel
    s = s.replaceAll(_tatweel, '');

    // lowercase
    s = s.toLowerCase();

    // normalize spaces
    s = s.replaceAll(_multiSpace, ' ').trim();

    return s;
  }
}
