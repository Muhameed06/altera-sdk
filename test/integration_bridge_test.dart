@Tags(['integration'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Live end-to-end test: drives the real SDK BridgeClient against a running
// backend, plus a raw "editor" socket, to prove the Dart side speaks the v2
// tree protocol correctly.
//
//   (cd ../backend && node src/server.js &)
//   flutter test --tags integration test/integration_bridge_test.dart
void main() {
  const url = 'ws://localhost:8080';
  const appId = 'integration-demo';

  test('app registers palette, editor restructures the tree, app sees it', () async {
    final client = BridgeClient(const BridgeConfig(url: url, appId: appId, token: 'app-secret-dev'));
    final state = LayoutState();
    client.messages.listen((msg) {
      switch (msg['type']) {
        case MessageType.stateSync:
          state.applyStateSync(Map<String, dynamic>.from(msg['screens']));
          break;
        case MessageType.layoutPatch:
          final node = LayoutNode.fromJson(Map<String, dynamic>.from(msg['tree']));
          if (node is ContainerNode) state.applyTree(msg['screen'] as String, node);
          break;
      }
    });

    client.connect();
    await _until(() => client.status.value == BridgeStatus.connected);

    // App declares its palette + a default column tree.
    final defaultTree = const ContainerNode(
      id: 'root',
      type: ContainerType.column,
      children: [
        LeafNode(id: 'n_featured', ref: 'featured'),
        LeafNode(id: 'n_music', ref: 'music'),
        LeafNode(id: 'n_favorites', ref: 'favorites'),
      ],
    );
    client.registerScreen('home', ['featured', 'music', 'favorites'], tree: defaultTree.toJson());
    await _until(() => state.treeFor('home')?.children.length == 3);

    // An editor restructures: wrap music+favorites in a FREE row with frames.
    final editor = WebSocketChannel.connect(Uri.parse(url));
    await editor.ready;
    editor.sink.add(jsonEncode({'type': 'connect_editor', 'appId': appId, 'token': 'editor-secret-dev'}));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    editor.sink.add(jsonEncode({
      'type': 'layout_set',
      'appId': appId,
      'screen': 'home',
      'tree': {
        'id': 'root',
        'kind': 'container',
        'type': 'column',
        'children': [
          {'id': 'n_featured', 'kind': 'leaf', 'ref': 'featured'},
          {
            'id': 'c_row',
            'kind': 'container',
            'type': 'row',
            'mode': 'free',
            'children': [
              {'id': 'n_music', 'kind': 'leaf', 'ref': 'music', 'frame': {'left': 10, 'top': 20}},
              {'id': 'n_favorites', 'kind': 'leaf', 'ref': 'favorites', 'frame': {'left': 160, 'top': 20}},
            ],
          },
        ],
      },
    }));

    await _until(() {
      final root = state.treeFor('home');
      if (root == null || root.children.length != 2) return false;
      return root.children[1] is ContainerNode;
    });
    final row = state.treeFor('home')!.children[1] as ContainerNode;
    expect(row.mode, ContainerMode.free);
    expect(row.type, ContainerType.row);
    final music = row.children[0] as LeafNode;
    expect(music.frame!.left, 10);
    expect(music.frame!.top, 20);

    await editor.sink.close();
    client.dispose();
  });
}

Future<void> _until(bool Function() condition, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
