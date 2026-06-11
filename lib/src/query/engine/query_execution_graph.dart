enum ExecNodeType {
  scan,
  indexScan,
  filter,
  join,
  sort,
  paginate
}

class ExecNode {

  final ExecNodeType type;

  final dynamic payload;

  ExecNode(this.type, this.payload);

}

class QueryExecutionGraph {

  final List<ExecNode> nodes = [];

  void add(ExecNode node) {
    nodes.add(node);
  }

}
