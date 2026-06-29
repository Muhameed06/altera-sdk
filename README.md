# ALTERA SDK — `live_ui_bridge`

Server-driven UI for Flutter. **Wrap your app once** and edit its live UI — text,
layout, order, colours, visibility — from the [ALTERA](https://altera-82d02.web.app)
dashboard. Ship changes in seconds, with no App Store review and no release.

- 🎁 **One wrapper does everything** — `RemoteScaffoldApp` builds your
  `MaterialApp`, bottom navigation and a scaffold per page, then **recursively
  decomposes your widget tree** so every `Text` (even inside a card) becomes an
  individually editable node. No `RemoteNode`, no manual ids, no per-screen setup.
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
