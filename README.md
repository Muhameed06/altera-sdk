# ALTERA SDK — `live_ui_bridge`

Server-driven UI for Flutter. **Wrap your app once** and edit its live UI — text,
layout, order, colours, visibility — from the [ALTERA](https://altera-82d02.web.app)
dashboard. Ship changes in seconds, with no App Store review and no release.

- 🎁 **New app?** `RemoteScaffoldApp` builds your `MaterialApp`, bottom navigation
  and a scaffold per page, then **recursively decomposes your widget tree** so
  every `Text` (even inside a card) becomes editable. No ids, no per-screen setup.
- 🧰 **Existing app?** Run `dart run live_ui_bridge:wrap` — it scans your screens
  and wraps them with `RemoteUI.auto`, keeping your **real** widgets but letting
  you reorder / hide / restyle them from the dashboard, live.
- 🧪 A/B test, roll out by %, schedule releases, diff and roll back — all driven
  from the dashboard.
- 🔌 Connects over WebSocket with a single API key.

## Install

```yaml
dependencies:
  live_ui_bridge:
    git:
      url: https://github.com/Muhameed06/altera-sdk.git
```

Then `flutter pub get`.

## Quick start — the one wrapper

```dart
import 'package:flutter/material.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

void main() => runApp(
      RemoteScaffoldApp(
        // Grab your apiKey from the ALTERA dashboard → Setup page.
        config: const RemoteAppConfig(apiKey: 'ak_your_key_here', environment: 'draft', editable: true),
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF7C3AED)),
        pages: [
          RemotePageDef(
            id: 'home',
            icon: Icons.home_rounded,
            label: 'Home',
            sections: [
              const Text('Welcome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Edit any of this live from your dashboard.'),
            ],
          ),
          RemotePageDef(
            id: 'profile',
            icon: Icons.person_rounded,
            label: 'Profile',
            sections: const [Text('Your Profile')],
          ),
        ],
      ),
    );
```

That's the whole integration. Open the dashboard and your pages, every text node
and the bottom bar are now editable — reorder, hide, restyle and rewrite copy in
real time, on every connected device.

> **Tip:** build your sections from **standard** widgets (`Container`, `Column`,
> `Row`, `Text`, `Card`, `Padding`…). The SDK decomposes those into editable
> nodes. A custom `StatelessWidget` class is treated as one opaque block — extract
> it into a helper function returning standard widgets if you want its inner text
> editable. See [`example/lib/main.dart`](example/lib/main.dart).

## Already have an app? Wrap your pages

`RemoteScaffoldApp` is for new apps where ALTERA owns the screen. For an
**existing** app, wrap each page's children with `RemoteUI.auto` — your real
widgets keep rendering and working; the dashboard just controls their order and
visibility, live.

### The fast way — the wrap tool

From your app's root directory:

```bash
# scan + report which screens can be wrapped (no changes)
dart run live_ui_bridge:wrap

# auto-wrap the clean screens (saves a .bak of every file it edits)
dart run live_ui_bridge:wrap --apply --key=ak_your_key_here
```

It writes a shared `lib/altera_config.dart`, auto-wraps the screens it can do
safely, and prints a copy-paste one-liner for the rest.

### By hand

```dart
import 'package:live_ui_bridge/live_ui_bridge.dart';

// In a screen's build(), wrap its children list once:
RemoteUI.auto(
  screen: 'home',
  editable: true,
  blocksOnly: true,            // render your real widgets as reorderable blocks
  config: const BridgeConfig(
    url: 'wss://altera-backend-1075554014912.europe-west1.run.app',
    appId: 'app',
    token: 'app-secret-dev',
    apiKey: 'ak_your_key_here',
    environment: 'draft',
  ),
  children: [
    yourHeader,    // your existing widgets — unchanged
    yourCardList,
    yourFooter,
  ],
);
```

> `blocksOnly: true` keeps each section pixel-perfect (rendered as your real
> widget) and reorderable as a whole block. Drop it to also decompose standard
> `Column`/`Row`/`Text` for finer, per-element editing.
>
> **Edit mode only shows while the dashboard is open** — close it and the app
> behaves like a normal app; reopen and editing returns.

## Configuration — `RemoteAppConfig`

| Field         | Default                | Notes                                                        |
| ------------- | ---------------------- | ------------------------------------------------------------ |
| `apiKey`      | —                      | Hosted accounts: your key resolves the tenant + endpoint.    |
| `url`         | `ws://localhost:8080`  | WebSocket endpoint (for self-hosting the backend).           |
| `token`       | `app-secret-dev`       | Auth token when self-hosting (ignored when `apiKey` is set). |
| `environment` | `production`           | `draft` while editing, `staging`, or `production` when live. |
| `editable`    | `false`                | `true` lets the dashboard select nodes + read geometry.      |

## Run the example

```bash
cd example
flutter run --dart-define=ALTERA_API_KEY=ak_your_key_here
# self-hosting the backend on an emulator? add:
#   --dart-define=ALTERA_URL=ws://10.0.2.2:8080
```

## Lower-level APIs (optional)

`RemoteScaffoldApp` is the recommended entry point. If you need finer control the
underlying pieces are also exported: `RemoteScaffold` (a single server-driven
page), `RemoteBottomBar`, `RemoteAppBar`, `RemoteNavigator`, `RemoteTheme`,
`BridgeClient`, and `RemoteApp` (whole-app text capture). Most apps never need
them.

## License

See the repository for license terms.
