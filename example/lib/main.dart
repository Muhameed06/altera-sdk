import 'package:flutter/material.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

import 'sections.dart';

void main() {
  kClient.connect();
  runApp(const DemoApp());
}

/// Connection settings, resolved from (in priority order):
///   1. URL query params  — used when embedded as Flutter Web in the dashboard,
///        e.g. http://localhost:8090/?appId=home-demo&edit=1&url=ws://...
///   2. --dart-define build flags — used on mobile/desktop, e.g.
///        flutter run -d DEVICE --dart-define=BRIDGE_URL=ws://10.0.2.2:8080
///                              --dart-define=EDIT=1
///   3. localhost defaults.
const _envUrl = String.fromEnvironment('BRIDGE_URL', defaultValue: 'ws://localhost:8080');
const _envAppId = String.fromEnvironment('BRIDGE_APP_ID', defaultValue: 'home-demo');
const _envToken = String.fromEnvironment('BRIDGE_TOKEN', defaultValue: 'app-secret-dev');
// Accept EDIT=1, EDIT=true (or EDIT=on) — bool.fromEnvironment only honours the
// exact string "true", which trips people up with `--dart-define=EDIT=1`.
const _envEditRaw = String.fromEnvironment('EDIT', defaultValue: '');
final _envEdit = _envEditRaw == '1' || _envEditRaw.toLowerCase() == 'true' || _envEditRaw == 'on';

BridgeConfig _buildConfig() {
  final q = Uri.base.queryParameters;
  // Edit-mode instances (the editor's own preview) render the live DRAFT;
  // standalone instances default to the published PRODUCTION layout.
  final edit = q['edit'] == '1' || _envEdit;
  final env = q['env'] ?? (edit ? 'draft' : 'production');
  return BridgeConfig(
    url: q['url'] ?? _envUrl,
    appId: q['appId'] ?? _envAppId,
    token: q['token'] ?? _envToken,
    environment: env,
  );
}

final kBridgeConfig = _buildConfig();

/// Edit mode lets the dashboard select nodes + read geometry (tap-to-select,
/// drag-drop). Enabled via `?edit=1` (web) or `--dart-define=EDIT=1`.
final kEditable = Uri.base.queryParameters['edit'] == '1' || _envEdit;

/// On-device edit chrome (outlines, drag handles, drop zones) drawn ON the
/// running app. OFF by default — editing is driven from the dashboard, so the
/// device stays a clean preview. Opt in with `?chrome=1` / `--dart-define=CHROME=1`.
const _envChromeRaw = String.fromEnvironment('CHROME', defaultValue: '');
final _envChrome = _envChromeRaw == '1' || _envChromeRaw.toLowerCase() == 'true';
final kChrome = Uri.base.queryParameters['chrome'] == '1' || _envChrome;

/// ONE shared connection for this device. Every screen + the navigator reuse it,
/// so the backend counts this app instance once (not once per screen).
final kClient = BridgeClient(kBridgeConfig);

final _defaultTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF5B8CFF),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0F1117),
);

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  // The whole-app theme is editable from the dashboard.
  late final RemoteTheme _theme = RemoteTheme(client: kClient)..addListener(_onTheme);
  void _onTheme() => setState(() {});

  @override
  void dispose() {
    _theme.removeListener(_onTheme);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the whole app once: this captures every on-screen text string into
    // the dashboard's Content page (live remote copy editing) — on top of the
    // per-section RemoteScaffold editing already wired below. Reuses kClient so
    // there's a single connection.
    return RemoteApp(
      config: RemoteAppConfig(editable: kEditable),
      client: kClient,
      child: MaterialApp(
        title: 'ALTERA Demo',
        debugShowCheckedModeBanner: false,
        theme: _theme.buildTheme(_defaultTheme),
        // Default text/icon color follows the theme; per-node style overrides win.
        builder: (context, child) {
          final onBg = Theme.of(context).colorScheme.onSurface;
          return RemoteAppRuntimeLayer(
            child: DefaultTextStyle(
              style: TextStyle(color: onBg, fontSize: 14, decoration: TextDecoration.none),
              child: IconTheme(data: IconThemeData(color: onBg), child: child!),
            ),
          );
        },
        home: const RootShell(),
      ),
    );
  }
}

/// App shell with a bottom nav. All three screens live in an [IndexedStack] so
/// they stay mounted — which means each one registers its layout with the
/// bridge immediately, and all three appear as tabs in the dashboard.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

/// Describes one bottom-nav page.
class _PageDef {
  const _PageDef(this.id, this.label, this.icon, this.page);
  final String id;
  final String label;
  final IconData icon;
  final Widget page;
}

class _RootShellState extends State<RootShell> {
  // Each page keyed by id so the IndexedStack preserves state across reorders.
  final List<_PageDef> _allPages = const [
    _PageDef('home', 'Home', Icons.home_rounded, HomeScreen(key: ValueKey('home'))),
    _PageDef('search', 'Search', Icons.search_rounded, SearchScreen(key: ValueKey('search'))),
    _PageDef('library', 'Library', Icons.library_music_rounded, LibraryScreen(key: ValueKey('library'))),
    _PageDef('profile', 'Profile', Icons.person_rounded, ProfileScreen(key: ValueKey('profile'))),
  ];

  late final RemoteNavigator _nav;
  String _currentId = 'home';

  @override
  void initState() {
    super.initState();
    // IMPORTANT: create eagerly (a lazy `late final` would never connect).
    _nav = RemoteNavigator(client: kClient)..addListener(_onBridge);
    // Declare the canonical page order so the dashboard shows a stable default
    // (not WebSocket arrival order). An editor's manual reorder overrides it.
    kClient.declarePageOrder([for (final p in _allPages) p.id]);
  }

  // Dashboard drove either a navigation request or a page reorder.
  void _onBridge() {
    final target = _nav.screen;
    if (target != null && target != _currentId && _allPages.any((p) => p.id == target)) {
      setState(() => _currentId = target);
    } else {
      setState(() {}); // page order may have changed
    }
  }

  @override
  void dispose() {
    _nav.removeListener(_onBridge);
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var index = _allPages.indexWhere((p) => p.id == _currentId);
    if (index < 0) index = 0;

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final p in _allPages) p.page]),
      // The bottom bar is now ALSO editable from the dashboard (region
      // 'bottombar'): reorder, hide, and restyle its tabs — no code change.
      bottomNavigationBar: RemoteBottomBar(
        region: 'bottombar',
        client: kClient,
        editable: kEditable,
        showEditChrome: kChrome,
        backgroundColor: const Color(0xFF181B24),
        currentId: _currentId,
        onSelect: (id) => setState(() => _currentId = id),
        items: [for (final p in _allPages) RemoteNavItem(id: p.id, icon: p.icon, label: p.label)],
      ),
    );
  }
}

// Each screen = one RemoteScaffold. Every child is editable from the dashboard
// (reorder, group, hide, style, free-position) — no RemoteNode, no manual ids.

void _noAction() {}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteScaffold(
      screen: 'home',
      client: kClient,
      editable: kEditable,
      showEditChrome: kChrome,
      // The app bar's title + action items are ALSO editable from the dashboard
      // (reorder / hide actions, edit & restyle the title) — region 'home.appbar'.
      appBar: RemoteAppBar(
        region: 'home.appbar',
        client: kClient,
        title: 'Home',
        backgroundColor: const Color(0xFF181B24),
        editable: kEditable,
        showEditChrome: kChrome,
        elements: const [
          IconButton(key: ValueKey('search'), icon: Icon(Icons.search), onPressed: _noAction, tooltip: 'Search'),
          IconButton(key: ValueKey('notifications'), icon: Icon(Icons.notifications_none), onPressed: _noAction),
          IconButton(key: ValueKey('settings'), icon: Icon(Icons.settings_outlined), onPressed: _noAction),
        ],
      ),
      children: const [
        FeaturedSection(key: ValueKey('featured')),
        MusicSection(key: ValueKey('music')),
        FavoritesSection(key: ValueKey('favorites')),
        RecentsSection(key: ValueKey('recents')),
      ],
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteScaffold(
      screen: 'search',
      client: kClient,
      editable: kEditable,
      showEditChrome: kChrome,
      appBar: AppBar(title: const Text('Search'), backgroundColor: const Color(0xFF181B24)),
      children: const [
        TrendingSection(key: ValueKey('trending')),
        CategoriesSection(key: ValueKey('categories')),
        RecentSearchesSection(key: ValueKey('recent_searches')),
      ],
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteScaffold(
      screen: 'library',
      client: kClient,
      editable: kEditable,
      showEditChrome: kChrome,
      appBar: AppBar(title: const Text('Library'), backgroundColor: const Color(0xFF181B24)),
      children: const [
        PlaylistsSection(key: ValueKey('playlists')),
        AlbumsSection(key: ValueKey('albums')),
        DownloadsSection(key: ValueKey('downloads')),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteScaffold(
      screen: 'profile',
      client: kClient,
      editable: kEditable,
      showEditChrome: kChrome,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: const Color(0xFF181B24)),
      children: const [
        ProfileHeaderSection(key: ValueKey('profile_header')),
        StatsSection(key: ValueKey('stats')),
        SettingsSection(key: ValueKey('settings')),
      ],
    );
  }
}
