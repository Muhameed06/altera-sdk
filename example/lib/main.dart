import 'package:flutter/material.dart';
import 'package:live_ui_bridge/live_ui_bridge.dart';

// ── ONE wrapper does everything. ─────────────────────────────────────────────
// RemoteScaffoldApp builds your MaterialApp + bottom navigation + a scaffold per
// page, AND recursively decomposes your widget tree — so every Text (even inside
// a card) becomes individually editable, reorderable and restylable from the
// ALTERA dashboard. No RemoteNode, no manual ids, no per-screen wrappers.
//
// Run it:
//   flutter run --dart-define=ALTERA_API_KEY=ak_your_key_here
//   (or pass --dart-define=ALTERA_URL=ws://10.0.2.2:8080 when self-hosting)

void main() => runApp(
      RemoteScaffoldApp(
        config: const RemoteAppConfig(
          // Hosted: paste your key from the ALTERA dashboard → Setup page,
          // or inject it at run time with --dart-define=ALTERA_API_KEY=ak_...
          apiKey: String.fromEnvironment('ALTERA_API_KEY', defaultValue: 'ak_REPLACE_ME'),
          url: String.fromEnvironment('ALTERA_URL', defaultValue: 'ws://localhost:8080'),
          environment: 'draft',
          editable: true,
        ),
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
        pages: [
          RemotePageDef(
            id: 'home',
            icon: Icons.home_rounded,
            label: 'Home',
            appBarTitle: 'Home',
            sections: [
              const Text('Welcome to ALTERA',
                  key: ValueKey('title'),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Edit and reorder any of this live from your dashboard.',
                  key: ValueKey('subtitle')),
              const Text('Featured',
                  key: ValueKey('featured'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              card('card1', 'Live updates', 'Change copy without an app release'),
              card('card2', 'No code', 'Edit straight from the dashboard'),
            ],
          ),
          RemotePageDef(
            id: 'profile',
            icon: Icons.person_rounded,
            label: 'Profile',
            appBarTitle: 'Profile',
            sections: [
              const Text('Your Profile',
                  key: ValueKey('p_title'),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Account details and settings live here.', key: ValueKey('p_sub')),
              card('p_card1', 'Account', 'Manage your details'),
              card('p_card2', 'Notifications', 'Email and push preferences'),
            ],
          ),
        ],
      ),
    );

// Built from STANDARD widgets (Container + Column + Text), so the SDK can
// decompose it — the card's title AND subtitle are editable text nodes too.
Widget card(String id, String title, String subtitle) {
  return Container(
    key: ValueKey(id),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF161A22),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            key: ValueKey('${id}_t'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle,
            key: ValueKey('${id}_s'),
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    ),
  );
}
