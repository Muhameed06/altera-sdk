# live_ui_bridge

Flutter SDK that exposes a widget tree as a remotely editable layout graph,
synced over WebSockets.

## Install

```yaml
dependencies:
  live_ui_bridge:
    path: ../flutter_sdk   # or a git/pub ref
```

## Usage

Wrap a screen's components in `RemoteUI`, giving each a `RemoteNode` with a
stable id:

```dart
RemoteUI(
  screen: 'home',
  config: const BridgeConfig(
    url: 'ws://localhost:8080',
    appId: 'home-demo',
    token: 'app-secret-dev',
  ),
  builder: (context, children) => ListView(children: children),
  nodes: const [
    RemoteNode(id: 'featured',  child: FeaturedSection()),
    RemoteNode(id: 'music',     child: MusicSection()),
    RemoteNode(id: 'favorites', child: FavoritesSection()),
  ],
)
```

The web editor can now reorder and hide/show these sections in real time.

## Pieces

| API            | Role                                                              |
| -------------- | ---------------------------------------------------------------- |
| `RemoteUI`     | Root container: registers nodes, connects, applies layout diffs, rebuilds in order |
| `RemoteNode`   | Wraps a component with a stable `id`                             |
| `LayoutState`  | `ChangeNotifier` holding `screen → order + hidden`; the layout source of truth |
| `NodeRegistry` | Maps node ids → declared `RemoteNode`s (dup-id detection)        |
| `BridgeClient` | WebSocket client (connect/register/auto-reconnect/ping)         |

`RemoteUI` creates its own `LayoutState` + `BridgeClient` by default, or you can
inject shared ones to drive it from **Provider** or **Riverpod**.

## How layout updates apply

1. On mount, `RemoteUI` declares its node ids → `LayoutState.registerDeclaredOrder`
   and reports them to the backend (`connect_app` with `order`).
2. The server returns the authoritative layout (`state_sync`); editor edits
   arrive as `layout_patch`.
3. `LayoutState` updates and notifies → `RemoteUI` rebuilds children in the new
   visible order. Server order wins; newly added widgets are appended, removed
   widgets are dropped.

## Tests

```bash
flutter test                                   # LayoutState unit tests
flutter test --tags integration \              # live e2e (needs backend running)
  test/integration_bridge_test.dart
```

See `example/` for a complete runnable app.
