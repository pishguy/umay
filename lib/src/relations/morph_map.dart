class MorphMap {

  static final Map<String, dynamic> _map = {};

  static void register(String name, dynamic box) {
    _map[name] = box;
  }

  static dynamic resolve(String name) {
    return _map[name];
  }

}
