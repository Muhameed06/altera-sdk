import 'remote_node.dart';

/// Maps node ids to their declared [RemoteNode]s within a single [RemoteUI]
/// scope. Detects duplicate ids early (they would corrupt the layout graph).
class NodeRegistry {
  final Map<String, RemoteNode> _nodes = {};

  /// Rebuild the registry from the nodes declared in code. Returns the list of
  /// ids in declaration order.
  List<String> register(List<RemoteNode> nodes) {
    _nodes.clear();
    final ids = <String>[];
    for (final node in nodes) {
      assert(
        !_nodes.containsKey(node.id),
        'Duplicate RemoteNode id "${node.id}" in the same RemoteUI screen.',
      );
      _nodes[node.id] = node;
      ids.add(node.id);
    }
    return ids;
  }

  RemoteNode? operator [](String id) => _nodes[id];

  Iterable<String> get ids => _nodes.keys;
}
