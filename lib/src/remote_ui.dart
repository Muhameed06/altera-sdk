import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Card;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'bridge_client.dart';
import 'web/geometry_channel.dart';
import 'edit_mode.dart';
import 'geometry_reporter.dart';
import 'layout_node.dart';
import 'layout_state.dart';
import 'protocol.dart';
import 'registry.dart';
import 'remote_node.dart';
import 'remote_renderer.dart';

/// Builds the default layout tree from the declared palette.
typedef DefaultLayoutBuilder = ContainerNode Function(List<String> palette);

/// Root container that makes a screen's layout remotely editable as a TREE.
///
/// Declare the available components as [RemoteNode]s (the palette). [RemoteUI]:
///   1. registers the palette + a default tree (registry + [LayoutState]),
///   2. connects to the bridge backend over WebSocket,
///   3. applies incoming `layout_patch` trees live — reorder, regroup into
///      rows/grids/stacks, hide, or free-position, with no rebuild/redeploy.
class RemoteUI extends StatefulWidget {
  const RemoteUI({
    required this.screen,
    required this.nodes,
    this.config,
    this.client,
    this.layoutState,
    this.defaultLayout,
    this.scrollable = true,
    this.editable = false,
    this.showEditChrome = true,
    this.hooks,
    super.key,
  }) : assert(config != null || client != null,
            'Provide either a BridgeConfig or a pre-built BridgeClient.');

  /// One-wrapper adoption: pass your existing [children] directly and the SDK
  /// auto-assigns stable ids — no `RemoteNode`, no ids to maintain. Wrap a
  /// single top-level container (typically a screen's root column) and all of
  /// its direct children become editable (reorder / hide / group / style /
  /// free-position).
  ///
  /// Ids are derived from each child's `Key` if it's a [ValueKey] (recommended
  /// for stable, readable ids), otherwise from `runtimeType` + position.
  ///
  /// ```dart
  /// RemoteUI.auto(
  ///   screen: 'home',
  ///   config: kBridgeConfig,
  ///   children: const [
  ///     FeaturedSection(key: ValueKey('featured')),
  ///     MusicSection(key: ValueKey('music')),
  ///   ],
  /// )
  /// ```
  factory RemoteUI.auto({
    required String screen,
    required List<Widget> children,
    BridgeConfig? config,
    BridgeClient? client,
    LayoutState? layoutState,
    DefaultLayoutBuilder? defaultLayout,
    bool scrollable = true,
    bool editable = false,
    bool showEditChrome = true,
    RenderHooks? hooks,
    BuildContext? context,
    bool deep = true,
    bool blocksOnly = false,
    Key? key,
  }) {
    final leaves = <RemoteNode>[]; // unknown widgets → registered + rendered as-is
    final used = <String>{};
    var deepCount = 0; // cap how many custom widgets we expand, to bound work

    String mkId(Widget w, String fallback) {
      final k = w.key;
      var id = (k is ValueKey && k.value != null) ? k.value.toString() : fallback;
      while (used.contains(id)) {
        id = '$id~';
      }
      used.add(id);
      return id;
    }

    late final LayoutNode Function(Widget w, String path) decompose;

    // Recursively turn a widget tree into an editable node tree. Known structural
    // widgets (Text, Column/Row, Container, Padding, Center, Card, SizedBox) are
    // decomposed so EVERY text at any depth becomes individually editable;
    // anything else stays an opaque leaf rendered as your original widget.
    List<LayoutNode> decomposeChildren(List<Widget> ws, String path) {
      final out = <LayoutNode>[];
      for (var i = 0; i < ws.length; i++) {
        out.add(decompose(ws[i], '${path}_$i'));
      }
      return out;
    }

    LayoutNode flexNode(Flex f, String path, {NodeStyle? style, double? padding}) => ContainerNode(
          id: mkId(f, 'box_$path'),
          type: f.direction == Axis.horizontal ? ContainerType.row : ContainerType.column,
          props: ContainerProps(padding: padding, crossAxis: _crossOf(f.crossAxisAlignment), mainAxis: _mainOf(f.mainAxisAlignment)),
          style: style,
          children: decomposeChildren(f.children, path),
        );

    decompose = (Widget w, String path) {
      if (w is Text && w.data != null) {
        return TextNode(id: mkId(w, 'txt_$path'), text: w.data!, style: _styleOfText(w.style));
      }
      if (w is Flex) return flexNode(w, path);
      if (w is Container) {
        final style = _containerStyle(w);
        final pad = _padOf(w.padding);
        final child = w.child;
        if (child is Flex) return flexNode(child, path, style: style, padding: pad);
        return ContainerNode(
          id: mkId(w, 'box_$path'),
          type: ContainerType.column,
          props: ContainerProps(padding: pad, crossAxis: 'stretch'),
          style: style,
          children: child == null ? const [] : [decompose(child, '${path}_0')],
        );
      }
      if (w is Card) {
        return ContainerNode(
          id: mkId(w, 'card_$path'),
          type: ContainerType.column,
          props: const ContainerProps(padding: 12),
          style: const NodeStyle(radius: 12),
          children: w.child == null ? const [] : [decompose(w.child!, '${path}_0')],
        );
      }
      if (w is Padding) {
        return ContainerNode(
          id: mkId(w, 'pad_$path'),
          type: ContainerType.column,
          props: ContainerProps(padding: _padOf(w.padding), crossAxis: 'stretch'),
          children: w.child == null ? const [] : [decompose(w.child!, '${path}_0')],
        );
      }
      if (w is Center || w is Align) {
        final child = (w as dynamic).child as Widget?;
        return ContainerNode(
          id: mkId(w, 'al_$path'),
          type: ContainerType.column,
          props: const ContainerProps(crossAxis: 'center'),
          children: child == null ? const [] : [decompose(child, '${path}_0')],
        );
      }
      if (w is SizedBox) {
        return PrimitiveNode(id: mkId(w, 'sp_$path'), prim: 'spacer', data: {'size': w.height ?? w.width ?? 8.0});
      }
      // Deep mode: transparently expand a custom StatelessWidget into ITS OWN
      // build output, so every text/row/column inside that class becomes
      // individually editable too — wrap the class, edit everything inside it.
      if (deep && context != null && w is StatelessWidget && deepCount < 80) {
        try {
          deepCount++;
          // ignore: invalid_use_of_protected_member
          final built = w.build(context);
          return decompose(built, '${path}_x');
        } catch (_) {
          // Can't build standalone (needs its own element/state) → stays a leaf.
        }
      }
      // Unknown / custom widget → opaque leaf (renders your original widget).
      final id = mkId(w, '${w.runtimeType}_$path');
      leaves.add(RemoteNode(id: id, child: w));
      return LeafNode(id: 'n_$id', ref: id);
    };

    // blocksOnly: keep each top-level child as an opaque leaf rendered exactly
    // as your real widget (no lossy decomposition) — so complex sections look
    // pixel-perfect and are reorderable/hideable as whole blocks.
    List<LayoutNode> topLevel() {
      if (!blocksOnly) return decomposeChildren(children, 's');
      final out = <LayoutNode>[];
      for (var i = 0; i < children.length; i++) {
        final w = children[i];
        if (w is SizedBox) {
          out.add(PrimitiveNode(id: mkId(w, 'sp_$i'), prim: 'spacer', data: {'size': w.height ?? w.width ?? 8.0}));
          continue;
        }
        final id = mkId(w, '${w.runtimeType}_$i');
        leaves.add(RemoteNode(id: id, child: w));
        out.add(LeafNode(id: 'n_$id', ref: id));
      }
      return out;
    }

    final topNodes = topLevel();

    ContainerNode layout(List<String> palette) => ContainerNode(
          id: 'root',
          type: ContainerType.column,
          props: const ContainerProps(gap: 12, padding: 4, crossAxis: 'stretch'),
          children: topNodes,
        );

    return RemoteUI(
      screen: screen,
      nodes: leaves,
      config: config,
      client: client,
      layoutState: layoutState,
      defaultLayout: defaultLayout ?? layout,
      scrollable: scrollable,
      editable: editable,
      showEditChrome: showEditChrome,
      hooks: hooks,
      key: key,
    );
  }

  static NodeStyle? _containerStyle(Container c) {
    String? bg;
    double? radius;
    final d = c.decoration;
    if (d is BoxDecoration) {
      bg = _hex(d.color);
      final br = d.borderRadius;
      if (br is BorderRadius) radius = br.topLeft.x;
    }
    bg ??= _hex(c.color);
    if (bg == null && radius == null) return null;
    return NodeStyle(background: bg, radius: radius);
  }

  static double? _padOf(EdgeInsetsGeometry? e) {
    if (e is EdgeInsets) {
      if (e.left != 0) return e.left;
      if (e.top != 0) return e.top;
    }
    return null;
  }

  static String? _crossOf(CrossAxisAlignment a) => switch (a) {
        CrossAxisAlignment.center => 'center',
        CrossAxisAlignment.end => 'end',
        CrossAxisAlignment.stretch => 'stretch',
        _ => 'start',
      };

  static String? _mainOf(MainAxisAlignment a) => switch (a) {
        MainAxisAlignment.center => 'center',
        MainAxisAlignment.end => 'end',
        MainAxisAlignment.spaceBetween => 'spaceBetween',
        MainAxisAlignment.spaceAround => 'spaceAround',
        _ => 'start',
      };

  // Lift a Text's explicit style into the node graph so it looks the same but is
  // fully editable from the dashboard.
  static NodeStyle? _styleOfText(TextStyle? s) {
    if (s == null) return null;
    return NodeStyle(
      fontSize: s.fontSize,
      fontWeight: _weightStr(s.fontWeight),
      textColor: _hex(s.color),
      letterSpacing: s.letterSpacing,
    );
  }

  static String? _weightStr(FontWeight? w) {
    if (w == null) return null;
    if (w == FontWeight.w400) return 'normal';
    if (w == FontWeight.w700) return 'bold';
    return 'w${w.value}';
  }

  static String? _hex(Color? c) =>
      c == null ? null : '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

  final String screen;

  /// The palette of editable components (id + widget).
  final List<RemoteNode> nodes;

  final BridgeConfig? config;
  final BridgeClient? client;
  final LayoutState? layoutState;

  /// Optional default tree (used until the server sends one). Defaults to a
  /// vertical Column of every node.
  final DefaultLayoutBuilder? defaultLayout;

  /// Wrap the rendered root in a scroll view (default true).
  final bool scrollable;

  /// When true, overlay drag handles / drop zones / free-drag so the layout can
  /// be edited directly in this running app (e.g. the dashboard simulator).
  final bool editable;

  /// When false (with [editable] true) the app stays functionally editable
  /// (tap-to-select + geometry for a dashboard mirror) but draws NO on-device
  /// edit chrome — a clean "looks like the real app" surface.
  final bool showEditChrome;

  /// Optional custom render hooks. If null and [editable] is true, the SDK
  /// installs its built-in edit overlay.
  final RenderHooks? hooks;

  @override
  State<RemoteUI> createState() => _RemoteUIState();
}

class _RemoteUIState extends State<RemoteUI> {
  late final NodeRegistry _registry;
  late final LayoutState _state;
  late final BridgeClient _client;
  late final LayoutTreeRenderer _renderer;
  RemoteEditController? _editController;
  GeometryReporter? _reporter;
  late final bool _ownsClient;
  late final bool _ownsState;

  @override
  void initState() {
    super.initState();
    _registry = NodeRegistry();
    _state = widget.layoutState ?? LayoutState();
    _ownsState = widget.layoutState == null;
    _client = widget.client ?? BridgeClient(widget.config!);
    _ownsClient = widget.client == null;

    RenderHooks? hooks = widget.hooks;
    if (hooks == null && widget.editable) {
      _editController = RemoteEditController(state: _state, client: _client, screen: widget.screen);
      hooks = EditRenderHooks(_editController!, chrome: widget.showEditChrome);
    }
    // Report node geometry in edit mode so the dashboard can overlay drop
    // targets — web posts to the parent frame, native sends over the WS bridge
    // (for a live device mirror).
    if (widget.editable) {
      _reporter = GeometryReporter(
        widget.screen,
        kIsWeb
            ? (p) => postGeometry(jsonEncode({...p, 'type': 'lub:geometry'}))
            : (p) => _client.reportGeometry(p),
      );
    }
    _renderer = LayoutTreeRenderer(registry: _registry, hooks: hooks, reporter: _reporter);

    _syncDeclaredNodes();
    _client.messages.listen(_onMessage);
    if (_ownsClient) _client.connect();
  }

  @override
  void didUpdateWidget(covariant RemoteUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDeclaredNodes();
  }

  void _syncDeclaredNodes() {
    final palette = _registry.register(widget.nodes);
    final defaultTree = (widget.defaultLayout ?? _columnOfAll)(palette);
    // Seed locally so the app paints immediately, then let the server confirm.
    _state.seed(widget.screen, ScreenLayout(palette: palette, tree: defaultTree));
    _client.registerScreen(widget.screen, palette, tree: defaultTree.toJson());
  }

  ContainerNode _columnOfAll(List<String> palette) => ContainerNode(
        id: 'root',
        type: ContainerType.column,
        props: const ContainerProps(gap: 16, padding: 16, crossAxis: 'stretch'),
        children: [for (final id in palette) LeafNode(id: 'n_$id', ref: id)],
      );

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case MessageType.stateSync:
        final screens = msg['screens'];
        if (screens is Map) _state.applyStateSync(Map<String, dynamic>.from(screens));
        if (msg['data'] is Map) _state.applyData(Map<String, dynamic>.from(msg['data']));
        break;
      case MessageType.data:
        if (msg['data'] is Map) _state.applyData(Map<String, dynamic>.from(msg['data']));
        break;
      case MessageType.layoutPatch:
        if (msg['screen'] == widget.screen && msg['tree'] is Map) {
          final node = LayoutNode.fromJson(Map<String, dynamic>.from(msg['tree']));
          if (node is ContainerNode) _state.applyTree(widget.screen, node);
        }
        break;
      case MessageType.selection:
        // An editor selected a node — highlight it here (no re-broadcast).
        if (msg['screen'] == widget.screen) {
          _editController?.selected.value = msg['nodeId'] as String?;
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _editController?.dispose();
    _reporter?.dispose();
    if (_ownsClient) _client.dispose();
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Rebuild on layout changes AND when a dashboard editor connects/leaves,
      // so edit chrome appears/disappears the moment the dashboard opens/closes.
      animation: Listenable.merge([_state, _client.editorPresent]),
      builder: (context, _) {
        final tree = _state.treeFor(widget.screen);
        if (tree == null) return const SizedBox.shrink();
        _renderer.data = _state.data; // resolve bindings against the latest data
        if (_reporter != null) _reporter!.dpr = MediaQuery.of(context).devicePixelRatio;
        final rendered = _renderer.build(context, tree);
        return widget.scrollable ? SingleChildScrollView(child: rendered) : rendered;
      },
    );
  }
}
