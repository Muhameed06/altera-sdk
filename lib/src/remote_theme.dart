import 'dart:async';

import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'protocol.dart';

/// Listens for the app's global theme from the dashboard and builds a
/// [ThemeData] from it, so a single edit recolors the whole app.
///
/// ```dart
/// final remoteTheme = RemoteTheme(client: kClient);
/// // in build: MaterialApp(theme: remoteTheme.buildTheme(myDefaultTheme))
/// ```
class RemoteTheme extends ChangeNotifier {
  RemoteTheme({BridgeConfig? config, BridgeClient? client})
      : assert(config != null || client != null),
        _client = client ?? BridgeClient(config!),
        _ownsClient = client == null {
    _sub = _client.messages.listen(_onMessage);
    if (_ownsClient) _client.connect();
  }

  final BridgeClient _client;
  final bool _ownsClient;
  late final StreamSubscription _sub;

  Map<String, dynamic>? _theme;
  Map<String, dynamic>? get theme => _theme;

  void _onMessage(Map<String, dynamic> msg) {
    if (msg['type'] == MessageType.theme && msg['theme'] is Map) {
      _theme = Map<String, dynamic>.from(msg['theme']);
      notifyListeners();
    } else if (msg['type'] == MessageType.stateSync && msg['theme'] is Map) {
      _theme = Map<String, dynamic>.from(msg['theme']);
      notifyListeners();
    }
  }

  /// Build a theme from the editor config, falling back to [fallback] for any
  /// unset field (and entirely if no theme has been set yet).
  ThemeData buildTheme(ThemeData fallback) {
    final t = _theme;
    if (t == null || t.isEmpty) return fallback;
    final brightness = t['brightness'] == 'light' ? Brightness.light : Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: _color(t['primary']) ?? const Color(0xFF5B8CFF),
      scaffoldBackgroundColor: _color(t['background']) ?? fallback.scaffoldBackgroundColor,
    );
  }

  static Color? _color(Object? hex) {
    if (hex is! String) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  @override
  void dispose() {
    _sub.cancel();
    if (_ownsClient) _client.dispose();
    super.dispose();
  }
}
