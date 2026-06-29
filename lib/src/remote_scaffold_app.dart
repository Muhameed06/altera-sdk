import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'protocol.dart';
import 'remote_app.dart' show RemoteAppConfig;
import 'remote_bottom_bar.dart';
import 'remote_navigator.dart';
import 'remote_scaffold.dart';

/// One page of a [RemoteScaffoldApp]. List your sections as plain Flutter
/// widgets — each (give it a `ValueKey`) becomes an editable node in that page's
/// Layers tree in the dashboard.
class RemotePageDef {
  const RemotePageDef({
    required this.id,
    required this.icon,
    required this.label,
    required this.sections,
    this.appBarTitle,
  });

  final String id;
  final IconData icon;
  final String label;
  final List<Widget> sections;
  final String? appBarTitle;
}

/// The **one-wrapper** way to get fully editable, *separated* pages in ALTERA.
///
/// Wrap your app ONCE: give it your pages (each a list of section widgets) and
/// it builds the whole thing — MaterialApp, a bottom nav, a `RemoteScaffold` per
/// page (so each page is its own editable Layers tree), and dashboard↔app
/// navigation. You never touch `RemoteScaffold`, screens, or the client.
///
/// ```dart
/// void main() => runApp(RemoteScaffoldApp(
///   config: const RemoteAppConfig(apiKey: 'ak_...', environment: 'draft', editable: true),
///   pages: const [
///     RemotePageDef(id: 'home', icon: Icons.home, label: 'Home', appBarTitle: 'Home', sections: [
///       Text('Welcome', key: ValueKey('title')),
///     ]),
///   ],
/// ));
/// ```
class RemoteScaffoldApp extends StatefulWidget {
  const RemoteScaffoldApp({
    required this.config,
    required this.pages,
    this.theme,
    super.key,
  });

  final RemoteAppConfig config;
  final List<RemotePageDef> pages;
  final ThemeData? theme;

  @override
  State<RemoteScaffoldApp> createState() => _RemoteScaffoldAppState();
}

class _RemoteScaffoldAppState extends State<RemoteScaffoldApp> {
  late final BridgeClient _client;
  late final RemoteNavigator _nav;
  int _index = 0;

  List<String> get _ids => [for (final p in widget.pages) p.id];

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _client = BridgeClient(BridgeConfig(
      url: c.url,
      appId: c.appId,
      token: c.token,
      apiKey: c.apiKey,
      environment: c.environment,
    ));
    _client.connect();
    _client.declarePageOrder(_ids);
    // Follow page-clicks from the dashboard → switch the active page here.
    _nav = RemoteNavigator(client: _client)..addListener(_onDashboardNav);
  }

  void _onDashboardNav() {
    final i = _ids.indexOf(_nav.screen ?? '');
    if (i >= 0 && i != _index) setState(() => _index = i);
  }

  void _select(int i) {
    if (i >= 0 && i != _index) setState(() => _index = i);
  }

  @override
  void dispose() {
    _nav.removeListener(_onDashboardNav);
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    final editable = widget.config.editable;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.theme ?? ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        // All pages stay mounted → each registers its own Layers tree at once.
        body: IndexedStack(
          index: _index,
          children: [
            for (final p in pages)
              RemoteScaffold(
                screen: p.id,
                client: _client,
                editable: editable,
                showEditChrome: false,
                padding: const EdgeInsets.all(20),
                appBar: p.appBarTitle != null ? AppBar(title: Text(p.appBarTitle!)) : null,
                children: p.sections,
              ),
          ],
        ),
        bottomNavigationBar: pages.length < 2
            ? null
            : RemoteBottomBar(
                region: 'bottombar',
                client: _client,
                editable: editable,
                showEditChrome: false,
                currentId: _ids[_index],
                onSelect: (id) => _select(_ids.indexOf(id)),
                items: [for (final p in pages) RemoteNavItem(id: p.id, icon: p.icon, label: p.label)],
              ),
      ),
    );
  }
}
