import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

void main() {
  const config = BridgeConfig(url: 'ws://localhost:8080', appId: 'a', token: 't');

  test('RemoteUI.auto derives ids from ValueKey, else type+index', () {
    final w = RemoteUI.auto(
      screen: 'home',
      config: config,
      children: const [
        SizedBox(key: ValueKey('hero')),
        Placeholder(),
        SizedBox(),
      ],
    );
    expect(w.nodes.map((n) => n.id).toList(), ['hero', 'Placeholder_1', 'SizedBox_2']);
  });

  test('RemoteUI.auto disambiguates duplicate keys', () {
    final w = RemoteUI.auto(
      screen: 'home',
      config: config,
      children: const [
        SizedBox(key: ValueKey('dup')),
        SizedBox(key: ValueKey('dup')),
      ],
    );
    final ids = w.nodes.map((n) => n.id).toList();
    expect(ids.first, 'dup');
    expect(ids.toSet().length, 2, reason: 'ids must stay unique');
  });
}
