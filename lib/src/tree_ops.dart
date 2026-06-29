// Map-based, immutable layout-tree operations used by in-app edit mode.
// Works directly on the JSON form (Map/List) so we can mutate + republish
// without needing copyWith on the sealed model. Mirrors web-editor/src/treeOps.js.

Map<String, dynamic> _clone(Map<String, dynamic> m) =>
    Map<String, dynamic>.from(_deep(m) as Map);

Object? _deep(Object? v) {
  if (v is Map) return {for (final e in v.entries) e.key: _deep(e.value)};
  if (v is List) return v.map(_deep).toList();
  return v;
}

bool _isContainer(Map node) => node['kind'] == 'container';

List<Map<String, dynamic>> _children(Map node) =>
    ((node['children'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

/// Returns the id of the parent of [id], or null if it's the root / not found.
String? findParentId(Map<String, dynamic> tree, String id, [String? parent]) {
  if (tree['id'] == id) return parent;
  if (_isContainer(tree)) {
    for (final c in _children(tree)) {
      final r = findParentId(c, id, tree['id'] as String);
      if (r != null) return r;
    }
  }
  return null;
}

Map<String, dynamic>? findNode(Map<String, dynamic> tree, String id) {
  if (tree['id'] == id) return tree;
  if (_isContainer(tree)) {
    for (final c in _children(tree)) {
      final r = findNode(c, id);
      if (r != null) return r;
    }
  }
  return null;
}

Map<String, dynamic> _mapNode(
    Map<String, dynamic> tree, String id, Map<String, dynamic> Function(Map<String, dynamic>) fn) {
  if (tree['id'] == id) return fn(_clone(tree));
  if (_isContainer(tree)) {
    final copy = _clone(tree);
    copy['children'] = _children(tree).map((c) => _mapNode(c, id, fn)).toList();
    return copy;
  }
  return tree;
}

/// Remove a node (root is never removed). Returns the new tree.
Map<String, dynamic> removeNode(Map<String, dynamic> tree, String id) {
  if (tree['id'] == id) return tree;
  Map<String, dynamic> walk(Map<String, dynamic> node) {
    if (!_isContainer(node)) return node;
    final copy = _clone(node);
    copy['children'] = _children(node).where((c) => c['id'] != id).map(walk).toList();
    return copy;
  }

  return walk(tree);
}

/// Insert [node] into container [parentId] at [index] (-1 = append).
Map<String, dynamic> insertChild(
    Map<String, dynamic> tree, String parentId, Map<String, dynamic> node, int index) {
  return _mapNode(tree, parentId, (parent) {
    if (!_isContainer(parent)) return parent;
    final children = _children(parent);
    final at = (index < 0 || index > children.length) ? children.length : index;
    children.insert(at, node);
    parent['children'] = children;
    return parent;
  });
}

/// Move [id] into [newParentId] at [index]. No-ops if it would create a cycle.
Map<String, dynamic> moveNode(
    Map<String, dynamic> tree, String id, String newParentId, int index) {
  final node = findNode(tree, id);
  if (node == null || id == tree['id']) return tree;
  if (findNode(node, newParentId) != null) return tree; // can't drop into own subtree
  final without = removeNode(tree, id);
  return insertChild(without, newParentId, node, index);
}

/// Set / merge the absolute frame of [id] (used in free mode).
Map<String, dynamic> setFrame(Map<String, dynamic> tree, String id, Map<String, num> frame) {
  return _mapNode(tree, id, (n) {
    final f = Map<String, dynamic>.from((n['frame'] as Map?) ?? const {});
    f.addAll(frame);
    n['frame'] = f;
    return n;
  });
}
