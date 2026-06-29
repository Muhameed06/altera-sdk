import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bridge_client.dart';
import 'protocol.dart';

/// Listens for `navigate` requests from the dashboard and exposes the most
/// recently requested screen, so a multi-screen app can follow the editor.
///
/// ```dart
/// final nav = RemoteNavigator(config: kBridgeConfig);
/// nav.addListener(() {
///   final i = screens.indexOf(nav.screen);
///   if (i >= 0) setState(() => index = i);
/// });
/// ```
class RemoteNavigator extends ChangeNotifier {
  RemoteNavigator({BridgeConfig? config, BridgeClient? client})
      : assert(config != null || client != null),
        _client = client ?? BridgeClient(config!),
        _ownsClient = client == null {
    _sub = _client.messages.listen(_onMessage);
    if (_ownsClient) _client.connect();
  }

  final BridgeClient _client;
  final bool _ownsClient;
  late final StreamSubscription _sub;

  String? _screen;
  List<String>? _pageOrder;

  /// The screen the dashboard last asked to show (null until first request).
  String? get screen => _screen;

  /// The editor-defined order of the app's pages/tabs (null if unset).
  List<String>? get pageOrder => _pageOrder;

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case MessageType.navigate:
        if (msg['screen'] is String) {
          _screen = msg['screen'] as String;
          notifyListeners();
        }
        break;
      case MessageType.pageOrder:
        _pageOrder = (msg['order'] as List?)?.map((e) => e.toString()).toList();
        notifyListeners();
        break;
      case MessageType.stateSync:
        if (msg['pageOrder'] is List) {
          final order = (msg['pageOrder'] as List).map((e) => e.toString()).toList();
          if (order.isNotEmpty) {
            _pageOrder = order;
            notifyListeners();
          }
        }
        break;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    if (_ownsClient) _client.dispose();
    super.dispose();
  }
}
