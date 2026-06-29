import 'package:flutter_test/flutter_test.dart';
import 'package:live_ui_bridge/src/tree_ops.dart';

Map<String, dynamic> sample() => {
      'id': 'root',
      'kind': 'container',
      'type': 'column',
      'children': [
        {'id': 'a', 'kind': 'leaf', 'ref': 'featured'},
        {
          'id': 'row',
          'kind': 'container',
          'type': 'row',
          'mode': 'free',
          'children': [
            {'id': 'b', 'kind': 'leaf', 'ref': 'music'},
          ],
        },
      ],
    };

void main() {
  group('tree_ops', () {
    test('findParentId', () {
      final t = sample();
      expect(findParentId(t, 'a'), 'root');
      expect(findParentId(t, 'b'), 'row');
      expect(findParentId(t, 'root'), isNull);
    });

    test('moveNode moves a leaf into another container', () {
      final t = moveNode(sample(), 'a', 'row', 0);
      final row = findNode(t, 'row')!;
      expect((row['children'] as List).map((c) => c['id']), ['a', 'b']);
      // root no longer directly contains 'a'
      expect((t['children'] as List).any((c) => c['id'] == 'a'), isFalse);
    });

    test('moveNode refuses to drop a node into its own subtree', () {
      final t = moveNode(sample(), 'row', 'b', 0); // b is inside row
      // unchanged
      expect(findParentId(t, 'row'), 'root');
    });

    test('setFrame merges position', () {
      var t = setFrame(sample(), 'b', {'left': 30, 'top': 40});
      expect(findNode(t, 'b')!['frame'], {'left': 30, 'top': 40});
      t = setFrame(t, 'b', {'left': 99});
      expect(findNode(t, 'b')!['frame'], {'left': 99, 'top': 40});
    });

    test('removeNode does not mutate the input', () {
      final original = sample();
      final t = removeNode(original, 'a');
      expect((t['children'] as List).length, 1);
      expect((original['children'] as List).length, 2); // input untouched
    });
  });
}
