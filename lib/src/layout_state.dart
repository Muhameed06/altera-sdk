import 'package:flutter/foundation.dart';

import 'layout_node.dart';

/// Per-screen layout: the [palette] of available leaf ids and the [tree] that
/// arranges them. Mirrors the backend's source of truth for one screen.
@immutable
class ScreenLayout {
  const ScreenLayout({required this.palette, required this.tree});

  final List<String> palette;
  final ContainerNode tree;

  factory ScreenLayout.fromJson(Map<String, dynamic> json) {
    final node = LayoutNode.fromJson(Map<String, dynamic>.from(json['tree'] ?? {}));
    return ScreenLayout(
      palette: (json['palette'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      tree: node is ContainerNode
          ? node
          : const ContainerNode(id: 'root', type: ContainerType.column, children: []),
    );
  }
}

/// Holds the layout tree for every screen and notifies listeners on change.
/// Backed by [ChangeNotifier] so it works with `setState`, Provider, or Riverpod.
class LayoutState extends ChangeNotifier {
  final Map<String, ScreenLayout> _screens = {};

  /// The data context that `{{bindings}}` and `when` conditions resolve
  /// against. Populated by the app and/or synced sample data from the editor.
  Map<String, dynamic> _data = const {};
  Map<String, dynamic> get data => _data;

  /// Replace the data context (from `data` message or `state_sync`).
  void applyData(Map<String, dynamic> next) {
    _data = next;
    notifyListeners();
  }

  ScreenLayout? layoutFor(String screen) => _screens[screen];
  ContainerNode? treeFor(String screen) => _screens[screen]?.tree;
  List<String> paletteFor(String screen) => _screens[screen]?.palette ?? const [];

  /// Replace a screen's full layout (from `state_sync` or `layout_patch`).
  void applyScreen(String screen, ScreenLayout layout) {
    _screens[screen] = layout;
    notifyListeners();
  }

  /// Apply a `layout_patch` carrying just `{ screen, tree }` — keeps the
  /// existing palette.
  void applyTree(String screen, ContainerNode tree) {
    final existing = _screens[screen];
    _screens[screen] = ScreenLayout(palette: existing?.palette ?? const [], tree: tree);
    notifyListeners();
  }

  /// Apply a full `state_sync` payload `{ screens: { name: {palette, tree} } }`.
  void applyStateSync(Map<String, dynamic> screensJson) {
    screensJson.forEach((name, value) {
      _screens[name] = ScreenLayout.fromJson(Map<String, dynamic>.from(value));
    });
    notifyListeners();
  }

  /// Seed a screen locally before the server responds (so the app renders
  /// immediately with its code-declared default).
  void seed(String screen, ScreenLayout layout) {
    _screens.putIfAbsent(screen, () => layout);
  }
}
