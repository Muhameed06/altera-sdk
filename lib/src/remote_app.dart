import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

import 'bridge_client.dart';
import 'protocol.dart';
import 'remote_theme.dart';

/// One-wrapper configuration for [RemoteApp]. In a hosted setup [apiKey]
/// resolves the endpoint + credentials; for local/self-host pass them directly.
class RemoteAppConfig {
  const RemoteAppConfig({
    this.apiKey,
    this.url = 'ws://localhost:8080',
    this.appId = 'app',
    this.token = 'app-secret-dev',
    this.environment = 'production',
    this.editable = false,
    this.userId,
    this.userContext,
  });

  /// Hosted key (resolves url/app/token server-side). Optional for self-host.
  final String? apiKey;
  final String url;
  final String appId;
  final String token;

  /// Which published deployment this build renders: draft | staging | production.
  final String environment;

  /// When true the app is selectable/inspectable from the dashboard (edit mode).
  final bool editable;

  /// Stable user id for consistent A/B variant bucketing (pass your logged-in
  /// user's id). If null, a per-launch id is used.
  final String? userId;

  /// Targeting attributes for experiment audiences, e.g. `{'country':'DE','tier':'pro'}`.
  final Map<String, dynamic>? userContext;
}

/// Runtime handle shared across the app — lets the [RemoteAppNavigatorObserver]
/// (created inside MaterialApp) reach the live connection without prop drilling.
class RemoteAppController {
  RemoteAppController({required this.client, required this.config, required this.theme});

  final BridgeClient client;
  final RemoteAppConfig config;
  final RemoteTheme theme;

  /// The most recently active RemoteApp (set on mount). The navigator observer
  /// reads this since it's constructed without a BuildContext.
  static RemoteAppController? instance;

  String? _screen;
  String? get screen => _screen;

  /// Surface the current route as an editable page in the dashboard.
  void setScreen(String? name) {
    if (name == null || name.isEmpty || name == _screen) return;
    _screen = name;
    client.registerScreen(name, const []);
  }
}

/// Wrap your whole app **once** to make it remote-aware: auto-connects, applies
/// live theme overrides, exposes the running app to the dashboard, and (with
/// [RemoteAppNavigatorObserver] + [RemoteAppRuntimeLayer]) auto-detects screens
/// and makes every element selectable — no per-widget wrapping.
///
/// ```dart
/// RemoteApp(
///   config: RemoteAppConfig(apiKey: '...'),
///   child: MaterialApp(
///     navigatorObservers: [RemoteAppNavigatorObserver()],
///     builder: (context, child) => RemoteAppRuntimeLayer(child: child!),
///   ),
/// )
/// ```
class RemoteApp extends StatefulWidget {
  const RemoteApp({required this.config, required this.child, this.client, super.key});

  final RemoteAppConfig config;
  final Widget child;

  /// Reuse an existing client (e.g. an app that already uses RemoteScaffold).
  /// When provided, RemoteApp won't open or close a second connection.
  final BridgeClient? client;

  static RemoteAppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RemoteAppScope>();
    assert(scope != null, 'RemoteApp.of() must be called below a RemoteApp.');
    return scope!.controller;
  }

  static RemoteAppController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RemoteAppScope>()?.controller;

  @override
  State<RemoteApp> createState() => _RemoteAppState();
}

class _RemoteAppState extends State<RemoteApp> {
  late final BridgeClient _client;
  late final bool _ownsClient;
  late final RemoteTheme _theme;
  late final RemoteAppController _controller;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    if (widget.client != null) {
      _client = widget.client!;
      _ownsClient = false;
    } else {
      _client = BridgeClient(BridgeConfig(url: c.url, appId: c.appId, token: c.token, environment: c.environment, apiKey: c.apiKey, userId: c.userId, userContext: c.userContext));
      _ownsClient = true;
    }
    _theme = RemoteTheme(client: _client)..addListener(_onChange);
    _controller = RemoteAppController(client: _client, config: c, theme: _theme);
    RemoteAppController.instance = _controller;
    if (_ownsClient) _client.connect();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _theme.removeListener(_onChange);
    _theme.dispose();
    if (_ownsClient) _client.dispose();
    if (identical(RemoteAppController.instance, _controller)) {
      RemoteAppController.instance = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _RemoteAppScope(controller: _controller, child: widget.child);
}

class _RemoteAppScope extends InheritedWidget {
  const _RemoteAppScope({required this.controller, required super.child});
  final RemoteAppController controller;
  @override
  bool updateShouldNotify(_RemoteAppScope old) => old.controller != controller;
}

/// Add to `MaterialApp.navigatorObservers` so every route you navigate to is
/// auto-registered as a page in the dashboard — no manual screen declarations.
class RemoteAppNavigatorObserver extends NavigatorObserver {
  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      RemoteAppController.instance?.setScreen(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _report(newRoute);
}

/// Place in `MaterialApp.builder` around `child`. Three jobs, all without
/// wrapping a single widget:
///   1. apply live remote **theme** overrides app-wide,
///   2. scan the render tree to **capture** on-screen text (so the dashboard can
///      list + remotely edit live copy) and re-apply text **overrides** every
///      frame (survives rebuilds),
///   3. hit-test taps to **select** the tapped element in the dashboard.
///
/// Capture/select run only in edit mode ([RemoteAppConfig.editable]); text
/// overrides apply always so published copy reaches real users.
///
/// Note: auto-ids are positional — robust for live copy/visibility, but a code
/// restructure can remap an override. Structural editing still uses RemoteUI.
class RemoteAppRuntimeLayer extends StatefulWidget {
  const RemoteAppRuntimeLayer({required this.child, super.key});
  final Widget child;

  @override
  State<RemoteAppRuntimeLayer> createState() => _RemoteAppRuntimeLayerState();
}

class _RemoteAppRuntimeLayerState extends State<RemoteAppRuntimeLayer> {
  final GlobalKey _scanKey = GlobalKey();
  RemoteAppController? _controller;
  StreamSubscription? _sub;
  Timer? _captureTimer;

  /// id -> override text ('' hides the text). Applied every frame.
  final Map<String, String> _overrides = {};

  /// id -> the element's ORIGINAL text, saved the first time we override it so
  /// "Undo" (removing the override) can restore it.
  final Map<String, String> _originals = {};

  @override
  void initState() {
    super.initState();
    // Each frame, apply overrides (so developer rebuilds can't clobber them) and
    // restore originals for any override that was just removed. Cheap no-op when
    // there's nothing pending.
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (mounted) _syncOverrides();
    });
  }

  void _attach(RemoteAppController c) {
    if (identical(_controller, c)) return;
    _controller = c;
    _sub?.cancel();
    _sub = c.client.messages.listen(_onMessage);
    _captureTimer?.cancel();
    if (c.config.editable) {
      _captureTimer = Timer.periodic(const Duration(seconds: 1), (_) => _capture());
    }
  }

  void _onMessage(Map<String, dynamic> msg) {
    if (msg['type'] == MessageType.setCapture && msg['overrides'] is Map) {
      _overrides
        ..clear()
        ..addAll(Map<String, String>.from(
            (msg['overrides'] as Map).map((k, v) => MapEntry('$k', '$v'))));
      WidgetsBinding.instance.ensureVisualUpdate(); // force a frame to apply
    }
  }

  // Walk the render tree in document order, calling [fn] for each text node.
  void _eachText(RenderObject ro, void Function(RenderParagraph) fn) {
    if (ro is RenderParagraph) fn(ro);
    ro.visitChildren((child) => _eachText(child, fn));
  }

  String get _screen => _controller?.screen ?? 'app';

  void _capture() {
    final root = _scanKey.currentContext?.findRenderObject();
    if (root == null || _controller == null) return;
    final items = <Map<String, dynamic>>[];
    var i = 0;
    _eachText(root, (p) {
      final id = 'txt#${i++}';
      if (!p.attached || !p.hasSize) return;
      final r = p.localToGlobal(Offset.zero) & p.size;
      items.add({
        'id': id,
        'text': p.text.toPlainText(),
        'rect': {'left': r.left, 'top': r.top, 'width': r.width, 'height': r.height},
      });
    });
    _controller!.client.reportCapture({'screen': _screen, 'items': items});
  }

  void _syncOverrides() {
    if (_overrides.isEmpty && _originals.isEmpty) return;
    final root = _scanKey.currentContext?.findRenderObject();
    if (root == null) return;
    var i = 0;
    _eachText(root, (p) {
      final id = 'txt#${i++}';
      final style = p.text is TextSpan ? (p.text as TextSpan).style : null;
      if (_overrides.containsKey(id)) {
        // Save the original once, then keep the override applied.
        _originals.putIfAbsent(id, () => p.text.toPlainText());
        final ov = _overrides[id]!;
        if (p.text.toPlainText() != ov) p.text = TextSpan(text: ov, style: style);
      } else if (_originals.containsKey(id)) {
        // Override was removed (Undo) → restore the original text.
        final orig = _originals.remove(id)!;
        if (p.text.toPlainText() != orig) p.text = TextSpan(text: orig, style: style);
      }
    });
  }

  void _onTapUp(PointerUpEvent e) {
    final root = _scanKey.currentContext?.findRenderObject();
    if (root == null || _controller == null) return;
    String? hitId;
    var i = 0;
    _eachText(root, (p) {
      final id = 'txt#${i++}';
      if (p.attached && p.hasSize && (p.localToGlobal(Offset.zero) & p.size).contains(e.position)) {
        hitId = id; // deepest in document order wins
      }
    });
    if (hitId != null) _controller!.client.select(_screen, hitId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _captureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = RemoteApp.maybeOf(context);
    if (controller == null) return widget.child; // not under a RemoteApp
    _attach(controller);

    Widget content = KeyedSubtree(key: _scanKey, child: widget.child);

    // Tap-to-select overlay (edit mode only) — non-blocking so the app stays usable.
    if (controller.config.editable) {
      content = Listener(behavior: HitTestBehavior.translucent, onPointerUp: _onTapUp, child: content);
    }

    final base = Theme.of(context);
    return AnimatedBuilder(
      animation: controller.theme,
      builder: (context, _) => Theme(data: controller.theme.buildTheme(base), child: content),
    );
  }
}
