// Demo of the ONE-WRAPPER model: plain Flutter widgets, no RemoteUI / RemoteNode
// anywhere. RemoteApp wraps the app once — its render-tree scanner captures all
// on-screen text, and you edit the copy live from the dashboard's Content (📝)
// panel. Live theming + tap-to-select come along for free.
//
// Run (Android emulator):
//   flutter run -t lib/main_remoteapp.dart -d emulator-5554 --dart-define=EDIT=1
// Then in the dashboard (appId "home-demo") open the 📝 Content panel.

import 'package:flutter/material.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

const _url = String.fromEnvironment('BRIDGE_URL', defaultValue: 'ws://localhost:8080');
const _appId = String.fromEnvironment('BRIDGE_APP_ID', defaultValue: 'home-demo');
const _editRaw = String.fromEnvironment('EDIT', defaultValue: '');
final _edit = _editRaw == '1' || _editRaw.toLowerCase() == 'true';

void main() => runApp(const StoreApp());

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoteApp(
      config: RemoteAppConfig(
        url: _url,
        appId: _appId,
        token: 'app-secret-dev',
        environment: _edit ? 'draft' : 'production',
        editable: _edit,
      ),
      child: MaterialApp(
        title: 'RemoteApp Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF5B8CFF), brightness: Brightness.dark),
        navigatorObservers: [RemoteAppNavigatorObserver()],
        builder: (context, child) => RemoteAppRuntimeLayer(child: child!),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Store')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text('Welcome back!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Summer sale — up to 50% off everything.', style: TextStyle(fontSize: 16)),
          SizedBox(height: 28),
          Text('Featured', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          _Card(title: 'New Arrivals', subtitle: 'Fresh styles for the season'),
          SizedBox(height: 12),
          _Card(title: 'Best Sellers', subtitle: 'What everyone is buying'),
          SizedBox(height: 28),
          Text('Tap any text — edit the copy live from the dashboard.',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }
}
