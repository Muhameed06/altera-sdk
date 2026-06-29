/// Flutter Live UI Bridge SDK (v2 — tree model).
///
/// Expose a Flutter widget tree as a remotely editable layout *graph* that a
/// web editor can restructure in real time over WebSockets: reorder, regroup
/// into rows/grids/stacks, hide, and free-position by x/y.
///
/// ```dart
/// RemoteUI(
///   screen: 'home',
///   config: const BridgeConfig(
///     url: 'ws://localhost:8080',
///     appId: 'home-demo',
///     token: 'app-secret-dev',
///   ),
///   nodes: const [
///     RemoteNode(id: 'featured',  child: FeaturedSection()),
///     RemoteNode(id: 'music',     child: MusicSection()),
///     RemoteNode(id: 'favorites', child: FavoritesSection()),
///   ],
/// )
/// ```
library;

export 'src/bridge_client.dart' show BridgeClient, BridgeStatus;
export 'src/edit_mode.dart' show RemoteEditController, EditRenderHooks;
export 'src/layout_node.dart'
    show
        LayoutNode,
        LeafNode,
        TextNode,
        PrimitiveNode,
        ContainerNode,
        ContainerType,
        ContainerMode,
        ContainerProps,
        NodeStyle,
        NodeOffset,
        NodeAnimation,
        Frame;
export 'src/layout_state.dart' show LayoutState, ScreenLayout;
export 'src/remote_navigator.dart' show RemoteNavigator;
export 'src/remote_theme.dart' show RemoteTheme;
export 'src/remote_app.dart'
    show RemoteApp, RemoteAppConfig, RemoteAppController, RemoteAppNavigatorObserver, RemoteAppRuntimeLayer;
export 'src/protocol.dart' show BridgeConfig, MessageType;
export 'src/registry.dart' show NodeRegistry;
export 'src/remote_node.dart' show RemoteNode;
export 'src/remote_app_bar.dart' show RemoteAppBar;
export 'src/remote_bottom_bar.dart' show RemoteBottomBar, RemoteNavItem;
export 'src/remote_renderer.dart' show LayoutTreeRenderer, RenderHooks;
export 'src/remote_scaffold.dart' show RemoteScaffold;
export 'src/remote_scaffold_app.dart' show RemoteScaffoldApp, RemotePageDef;
export 'src/remote_ui.dart' show RemoteUI, DefaultLayoutBuilder;
