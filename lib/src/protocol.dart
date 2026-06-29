/// WebSocket protocol constants — mirror of backend/src/protocol.js.
class MessageType {
  static const connectApp = 'connect_app';
  static const connectEditor = 'connect_editor';
  static const layoutSet = 'layout_set';
  static const select = 'select';
  static const navigate = 'navigate';
  static const setPageOrder = 'set_page_order';
  static const declarePageOrder = 'declare_page_order';
  static const pageOrder = 'page_order';
  static const setTheme = 'set_theme';
  static const theme = 'theme';
  static const setData = 'set_data';
  static const data = 'data';
  static const geometry = 'geometry';
  static const capture = 'capture'; // app -> server -> editors: auto-captured text/elements
  static const setCapture = 'set_capture'; // editor -> server -> app: text/visibility overrides
  static const autoLayout = 'auto_layout'; // app -> server -> editors: structural tree scanned from the live render tree (RemoteApp)
  static const appFrame = 'app_frame'; // app -> server -> editors: streamed PNG screenshot of the running app (live mirror, no adb)
  static const ping = 'ping';

  static const stateSync = 'state_sync';
  static const layoutPatch = 'layout_patch';
  static const selection = 'selection';
  static const connected = 'connected';
  static const error = 'error';
  static const pong = 'pong';
  static const presence = 'presence';
  static const publish = 'publish';
  static const publishStatus = 'publish_status';
}

/// Connection settings for a [BridgeClient].
class BridgeConfig {
  const BridgeConfig({
    required this.url,
    required this.appId,
    required this.token,
    this.environment = 'production',
    this.autoReconnect = true,
    this.apiKey,
    this.userId,
    this.userContext,
  });

  /// WebSocket endpoint, e.g. `ws://localhost:8080`.
  final String url;

  /// Sandbox/session identifier shared with the editor.
  final String appId;

  /// Auth token presented as a Flutter app (role = app).
  final String token;

  /// Per-user API key (from the ALTERA dashboard). When set, it identifies the
  /// owner account and their tenant — preferred over [appId]/[token]. Serving a
  /// published (staging/production) build requires the owner to have an active
  /// subscription.
  final String? apiKey;

  /// Deployment this instance renders: `draft` (live, unpublished — used by the
  /// editor's own preview), `staging`, or `production` (default, for end users).
  final String environment;

  final bool autoReconnect;

  /// Stable identifier for the current user, used to bucket them consistently
  /// into A/B test variants. If null, a per-launch id is generated (so each app
  /// instance still splits across variants, but not stably across restarts).
  /// Pass your real logged-in user id for proper, persistent experiments.
  final String? userId;

  /// Optional targeting attributes the editor can target an audience on, e.g.
  /// `{'country': 'DE', 'tier': 'pro', 'appVersion': '2.1.0'}`. `platform` is
  /// added automatically.
  final Map<String, dynamic>? userContext;
}
