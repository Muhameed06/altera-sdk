import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'protocol.dart';

enum BridgeStatus { disconnected, connecting, connected, error }

/// Thin WebSocket client for the Flutter app side of the bridge.
///
/// Connects as an `app`, registers screen layouts, and surfaces decoded server
/// messages on [messages]. Reconnects automatically with backoff when the
/// connection drops (if [BridgeConfig.autoReconnect] is set).
class BridgeClient {
  BridgeClient(this.config);

  final BridgeConfig config;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _disposed = false;
  int _backoffMs = 500;

  /// Screens the app has declared, replayed on every (re)connect so the server
  /// always knows the current widget inventory.
  final Map<String, Map<String, dynamic>> _declaredScreens = {};

  /// The app's canonical page order, replayed on (re)connect.
  List<String>? _declaredPageOrder;

  final _statusNotifier = ValueNotifier<BridgeStatus>(BridgeStatus.disconnected);
  ValueListenable<BridgeStatus> get status => _statusNotifier;

  /// True only while at least one dashboard editor is watching this session.
  /// On-device edit affordances (selection, drag handles, outlines) gate on
  /// this — so the moment you close the dashboard, the app stops being editable.
  final editorPresent = ValueNotifier<bool>(false);

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect() {
    if (_disposed) return;
    _statusNotifier.value = BridgeStatus.connecting;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(config.url));
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      // The handshake + screen registration must wait until the socket is open.
      channel.ready.then((_) {
        _statusNotifier.value = BridgeStatus.connected;
        _backoffMs = 500;
        _sendConnectApp();
        _declaredScreens.forEach((screen, payload) {
          _send({...payload, 'type': MessageType.connectApp});
        });
        if (_declaredPageOrder != null) {
          _send({'type': MessageType.declarePageOrder, 'order': _declaredPageOrder});
        }
        _startPing();
      }).catchError((_) {
        _onClosed();
      });
    } catch (_) {
      _onClosed();
    }
  }

  /// Identifies this running instance to the dashboard's device list.
  static final Map<String, dynamic> _device = {
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  };

  /// Per-launch fallback id so un-instrumented apps still split across variants.
  late final String _launchId =
      'u_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${identityHashCode(this).toRadixString(36)}';

  /// User context for A/B bucketing + audience targeting. Stable [userId] keeps a
  /// user on the same variant; [platform] is filled in automatically.
  Map<String, dynamic> get _context => {
        'userId': config.userId ?? _launchId,
        'platform': _device['platform'],
        ...?config.userContext,
      };

  void _sendConnectApp() {
    // Register every known screen on connect; if none yet, send a bare handshake.
    if (_declaredScreens.isEmpty) {
      _send({
        'type': MessageType.connectApp,
        'appId': config.appId,
        'token': config.token,
        if (config.apiKey != null) 'apiKey': config.apiKey,
        'env': config.environment,
        'device': _device,
        'context': _context,
      });
    }
  }

  /// Tell the server which leaf widgets this app can render for [screen] (the
  /// palette) plus an optional default [tree]. Called by RemoteUI as it mounts;
  /// replayed automatically across reconnects.
  void registerScreen(String screen, List<String> palette, {Map<String, dynamic>? tree, String? kind}) {
    _declaredScreens[screen] = {
      'appId': config.appId,
      'token': config.token,
      if (config.apiKey != null) 'apiKey': config.apiKey,
      'env': config.environment,
      'device': _device,
      'context': _context,
      'screen': screen,
      'palette': palette,
      if (tree != null) 'tree': tree,
      if (kind != null) 'kind': kind, // 'page' | 'widget' — for the dashboard split
    };
    _send({
      'type': MessageType.connectApp,
      ..._declaredScreens[screen]!,
    });
  }

  /// Declare the app's canonical page/tab order. Used as the default ordering
  /// in the editor; an editor's manual reorder takes precedence. Replayed on
  /// every (re)connect.
  void declarePageOrder(List<String> order) {
    _declaredPageOrder = order;
    _send({'type': MessageType.declarePageOrder, 'order': order});
  }

  /// Replace the whole layout tree for [screen] (used by in-app edit mode).
  void setTree(String screen, Map<String, dynamic> tree) {
    _send({
      'type': MessageType.layoutSet,
      'appId': config.appId,
      'screen': screen,
      'tree': tree,
    });
  }

  /// Report node geometry (edit mode) so the dashboard can overlay drop targets
  /// on a live device mirror. [payload] is { screen, rects, dpr }.
  void reportGeometry(Map<String, dynamic> payload) {
    _send({'type': MessageType.geometry, 'appId': config.appId, ...payload});
  }

  /// Report auto-captured text/elements (RemoteApp render-tree scan) so the
  /// dashboard can list + remotely edit live copy. [payload] is { screen, items }.
  void reportCapture(Map<String, dynamic> payload) {
    _send({'type': MessageType.capture, 'appId': config.appId, ...payload});
  }

  /// Report a structural tree scanned from the live render tree (RemoteApp), so
  /// the dashboard's Layers panel reflects the app's structure with one wrapper.
  void reportAutoLayout(Map<String, dynamic> payload) {
    _send({'type': MessageType.autoLayout, 'appId': config.appId, ...payload});
  }

  /// Stream a PNG screenshot of the running app so the dashboard can mirror the
  /// live screen with no adb/scrcpy (works on cloud, any device). [payload] is
  /// { screen, png (base64), w, h }.
  void reportAppFrame(Map<String, dynamic> payload) {
    _send({'type': MessageType.appFrame, 'appId': config.appId, ...payload});
  }

  /// Broadcast a node selection for collaboration/highlighting.
  void select(String screen, String? nodeId) {
    _send({
      'type': MessageType.select,
      'appId': config.appId,
      'screen': screen,
      'nodeId': nodeId,
    });
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == MessageType.presence) {
          editorPresent.value = ((decoded['editors'] as num?) ?? 0) > 0;
        }
        _messageController.add(decoded);
      }
    } catch (e) {
      debugPrint('[bridge] failed to decode message: $e');
    }
  }

  void _onClosed() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel = null;
    editorPresent.value = false; // lost the connection → no editor → not editable
    if (_disposed) return;
    _statusNotifier.value = BridgeStatus.disconnected;
    if (config.autoReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), connect);
      _backoffMs = (_backoffMs * 2).clamp(500, 10000);
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _send({'type': MessageType.ping, 't': DateTime.now().millisecondsSinceEpoch});
    });
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[bridge] send failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close(ws_status.normalClosure);
    _messageController.close();
    _statusNotifier.dispose();
  }
}
