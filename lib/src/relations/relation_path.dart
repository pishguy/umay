class RelationPath {

  final List<String> segments;

  RelationPath(String path)
      : segments = path.split(".");

}
