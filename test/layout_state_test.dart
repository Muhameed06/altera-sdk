import 'package:flutter_test/flutter_test.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

void main() {
  group('LayoutNode JSON', () {
    test('round-trips a nested tree with free frames and visibility', () {
      final json = {
        'id': 'root',
        'kind': 'container',
        'type': 'column',
        'mode': 'flow',
        'props': {'gap': 16, 'padding': 8, 'crossAxis': 'stretch'},
        'children': [
          {'id': 'n_a', 'kind': 'leaf', 'ref': 'a'},
          {
            'id': 'c_row',
            'kind': 'container',
            'type': 'row',
            'mode': 'free',
            'props': {'mainAxis': 'spaceBetween'},
            'children': [
              {'id': 'n_b', 'kind': 'leaf', 'ref': 'b', 'frame': {'left': 10.0, 'top': 20.0}},
              {'id': 'n_c', 'kind': 'leaf', 'ref': 'c', 'visible': false},
            ],
          },
        ],
      };
      final node = LayoutNode.fromJson(json) as ContainerNode;
      expect(node.type, ContainerType.column);
      expect(node.props.gap, 16);
      final row = node.children[1] as ContainerNode;
      expect(row.mode, ContainerMode.free);
      final b = row.children[0] as LeafNode;
      expect(b.frame!.left, 10);
      expect((row.children[1] as LeafNode).visible, false);

      // toJson preserves structure
      final back = node.toJson();
      expect(back['type'], 'column');
      expect((back['children'] as List).length, 2);
    });

    test('parses a text node with style', () {
      final node = LayoutNode.fromJson({
        'id': 't1',
        'kind': 'text',
        'text': 'Hello',
        'style': {'textColor': '#ff0000', 'fontSize': 24},
      });
      expect(node, isA<TextNode>());
      expect((node as TextNode).text, 'Hello');
      expect(node.style!.textColor, '#ff0000');
      expect(node.toJson()['kind'], 'text');
    });
  });

  group('LayoutState', () {
    test('applyStateSync hydrates palette + tree', () {
      final state = LayoutState();
      state.applyStateSync({
        'home': {
          'palette': ['a', 'b'],
          'tree': {
            'id': 'root',
            'kind': 'container',
            'type': 'column',
            'children': [
              {'id': 'n_a', 'kind': 'leaf', 'ref': 'a'},
            ],
          },
        },
      });
      expect(state.paletteFor('home'), ['a', 'b']);
      expect(state.treeFor('home')!.children.length, 1);
    });

    test('applyTree replaces tree but keeps palette', () {
      final state = LayoutState();
      state.applyScreen(
        'home',
        const ScreenLayout(
          palette: ['a', 'b'],
          tree: ContainerNode(id: 'root', type: ContainerType.column, children: []),
        ),
      );
      state.applyTree(
        'home',
        const ContainerNode(
          id: 'root',
          type: ContainerType.row,
          children: [LeafNode(id: 'n_a', ref: 'a')],
        ),
      );
      expect(state.paletteFor('home'), ['a', 'b']); // preserved
      expect(state.treeFor('home')!.type, ContainerType.row);
    });

    test('notifies listeners on change', () {
      final state = LayoutState();
      var count = 0;
      state.addListener(() => count++);
      state.applyTree('home', const ContainerNode(id: 'root', type: ContainerType.column, children: []));
      expect(count, 1);
    });
  });
}
