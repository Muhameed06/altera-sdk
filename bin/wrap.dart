// ignore_for_file: unnecessary_brace_in_string_interps
// ALTERA wrap tool — `dart run live_ui_bridge:wrap`
//
// Scans your Flutter app's lib/, finds every widget's build() method, and wraps
// each one's section list (a Column/ListView's `children:`) with RemoteUI.auto —
// so every page becomes reorderable / hideable / editable from the dashboard,
// while still rendering your real widgets.
//
//   dart run live_ui_bridge:wrap                 # scan + report (no changes)
//   dart run live_ui_bridge:wrap --apply         # wrap every class (backs up *.bak)
//   dart run live_ui_bridge:wrap --key=ak_xxx    # bake your dashboard key into the config
//
import 'dart:io';

const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _magenta = '\x1B[35m';

void _p(String s) => stdout.writeln(s);

class Target {
  Target(this.name, this.id, this.open, this.close, this.kind, this.axis);
  final String name; // the widget/screen class name
  final String id; // dashboard page id (slug)
  final int open; // offset just after the children list's '['
  final int close; // offset of the matching ']'
  final String kind; // 'page' (Scaffold) | 'widget' (reusable component)
  final String axis; // 'column' | 'row'
}

void main(List<String> args) {
  final apply = args.contains('--apply');
  final keyArg = args.firstWhere((a) => a.startsWith('--key='), orElse: () => '');
  final key = keyArg.isEmpty ? '' : keyArg.substring('--key='.length);
  // --local → point at your machine's backend (10.0.2.2 reaches localhost from
  // an Android emulator). --url=… to override.
  final local = args.contains('--local');
  // Wrap EVERY widget's build by default — reusable widgets AND Scaffold pages —
  // so the whole app becomes editable. Pass --pages-only to restrict to screens.
  _includeWidgets = !args.contains('--pages-only');
  final urlArg = args.firstWhere((a) => a.startsWith('--url='), orElse: () => '');
  final url = urlArg.isNotEmpty
      ? urlArg.substring('--url='.length)
      : (local ? 'ws://10.0.2.2:8080' : 'wss://altera-backend-1075554014912.europe-west1.run.app');

  _p('');
  _p('$_bold${_magenta}▲ ALTERA — wrap your pages$_reset');
  _p('${_dim}Make every screen editable from the dashboard.$_reset');
  _p('');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    _p('$_yellow✗ No lib/ directory here. Run this from your Flutter app root.$_reset');
    exit(1);
  }

  _writeConfig(key, url);

  var wrapped = 0, classesWrapped = 0;

  for (final f in libDir.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart') || f.path.contains('/gen/')) continue;
    if (f.path.endsWith('altera_config.dart')) continue;

    var src = f.readAsStringSync();
    if (!src.contains('build(') || src.contains('RemoteUI.auto(')) continue;

    final targets = _findTargets(src);
    if (targets.isEmpty) continue;

    for (final t in targets) {
      _p('  $_green● $_reset$_bold${t.name}$_reset $_dim→ ${t.kind} "${t.id}"  (${f.path})$_reset');
    }

    if (apply) {
      // Apply both insertions for every target, from the highest offset down so
      // earlier offsets stay valid.
      final edits = <List<dynamic>>[]; // [offset, text]
      for (final t in targets) {
        edits.add([t.close, '])']); // ])
        edits.add([t.open, _wrapOpen(t.id, t.kind, t.axis)]);
      }
      edits.sort((a, b) => (b[0] as int).compareTo(a[0] as int));
      for (final e in edits) {
        final at = e[0] as int;
        src = src.substring(0, at) + (e[1] as String) + src.substring(at);
      }
      // We just inserted a (non-const) RemoteUI.auto as the sole element of what
      // may have been a `const [...]` list — drop that `const` so it compiles.
      src = src.replaceAll(RegExp(r'\bconst\s*\[RemoteUI\.auto\('), '[RemoteUI.auto(');
      src = _ensureImports(src);
      f.copySync('${f.path}.bak');
      f.writeAsStringSync(src);
      wrapped++;
      classesWrapped += targets.length;
    }
  }

  if (apply) _wrapMain();

  _p('');
  if (apply) {
    _p('$_green✓ Wrapped $classesWrapped class${classesWrapped == 1 ? '' : 'es'} across $wrapped file${wrapped == 1 ? '' : 's'}$_reset ${_dim}(originals saved as *.bak)$_reset');
  } else {
    _p('${_bold}$classesWrappedDryRun$_reset');
  }
  _p('');
  _p('${_bold}Next:$_reset');
  _p('  ${_cyan}1.$_reset ${apply ? 'run' : 'add --apply to wrap them, then run'} your app:  flutter run');
  _p('  ${_cyan}2.$_reset open ${_cyan}https://altera-82d02.web.app$_reset, pick a page, drag to reorder — live on the device.');
  _p('${_dim}  Skipped lists with Expanded/Flexible/Spacer (they need a Flex parent) — wrap those by hand.$_reset');
  _p('');
}

// Set after the scan loop in dry-run mode (counts classes that WOULD be wrapped).
String get classesWrappedDryRun => _dryCount == 0
    ? 'No wrappable sections found.'
    : 'Found $_dryCount class${_dryCount == 1 ? '' : 'es'} to wrap — re-run with --apply.';
int _dryCount = 0;

// Wrap lib/main.dart's runApp(...) with AlteraMirror so the dashboard can mirror
// the live screen over the shared client (one device, no adb).
void _wrapMain() {
  final f = File('lib/main.dart');
  if (!f.existsSync()) return;
  var src = f.readAsStringSync();
  if (src.contains('AlteraMirror(')) return;
  final m = RegExp(r'runApp\s*\(').firstMatch(src);
  if (m == null) return;
  final open = m.end - 1; // index of '('
  final close = _matchBracket(src, open);
  if (close < 0) return;
  final arg = src.substring(open + 1, close);
  src = src.substring(0, m.start) +
      'runApp(AlteraMirror(client: alteraClient, child: $arg))' +
      src.substring(close + 1);
  src = _ensureImports(src);
  f.copySync('lib/main.dart.bak');
  f.writeAsStringSync(src);
  _p('$_green✓ Wrapped runApp with AlteraMirror (live screen mirror)$_reset');
}

String _wrapOpen(String id, String kind, String axis) =>
    // blocksOnly:true → render your REAL widgets untouched (Stacks, buttons,
    //   overlays all intact); reorder/hide them as whole blocks. This is the
    //   safe mode — full decompose breaks complex/interactive widgets.
    // showEditChrome:false → highlight/tap-to-select only, no on-device chrome.
    // client: alteraClient → ALL screens share ONE connection = one device.
    // kind → Pages vs Widgets grouping; axis → row/column section.
    "RemoteUI.auto(screen: '$id', kind: '$kind', axis: '$axis', editable: true, showEditChrome: false, scrollable: false, client: alteraClient, children: [";

// ── Find every build()'s first safe section list ─────────────────────────────
List<Target> _findTargets(String src) {
  final out = <Target>[];
  final builds = RegExp(r'\bbuild\s*\(\s*BuildContext').allMatches(src).toList();
  for (var i = 0; i < builds.length; i++) {
    final from = builds[i].start;
    final to = i + 1 < builds.length ? builds[i + 1].start : src.length;
    // Wrap EVERY widget (default). Screens (build returns a Scaffold) are tagged
    // 'page'; everything else is a reusable 'widget'. --pages-only restricts to
    // screens. The decomposer keeps complex/interactive widgets as faithful
    // leaves, so re-hosting stays pixel-safe.
    final isPage = src.substring(from, to).contains('Scaffold(');
    if (!isPage && !_includeWidgets) continue;
    final list = _firstListIn(src, from, to);
    if (list == null) continue;
    final name = _screenNameFor(src, from);
    out.add(Target(name, _slug(name), list.$1, list.$2, isPage ? 'page' : 'widget', list.$3));
    _dryCount++;
  }
  return out;
}

// Opt-in widget wrapping (off by default — keeps the app pixel-safe).
bool _includeWidgets = false;

// First `Column/Row/ListView` … `children: [ … ]` in [from,to) that's safe to
// wrap. Returns (openOffset, closeOffset, axis).
(int, int, String)? _firstListIn(String src, int from, int to) {
  // Column/ListView only. NEVER Row — wrapping a Row with flex children (e.g. an
  // Expanded label in a button) crashes with unbounded-width constraints.
  final re = RegExp(r'\b(Column|ListView)\s*\(');
  for (final m in re.allMatches(src.substring(from, to))) {
    const axis = 'column';
    final parenOpen = from + m.end - 1; // index of '('
    final parenClose = _matchBracket(src, parenOpen);
    if (parenClose < 0) continue;
    final inner = src.substring(parenOpen, parenClose);
    final cm = RegExp(r'children:\s*(?:const\s+)?\[').firstMatch(inner);
    if (cm == null) continue;
    final bracketOpen = parenOpen + cm.end - 1; // index of '['
    final bracketClose = _matchBracket(src, bracketOpen);
    if (bracketClose < 0) continue;
    final contents = src.substring(bracketOpen + 1, bracketClose);
    if (contents.trim().isEmpty) continue;
    // (decomposer handles Spacer/Expanded/Flexible safely — no need to skip)
    return (bracketOpen + 1, bracketClose, axis);
  }
  return null;
}

// The screen name for the build at [offset]: the nearest preceding widget class,
// resolving `State<X>` to `X` so a StatefulWidget's State maps to the widget.
String _screenNameFor(String src, int offset) {
  var name = 'screen';
  for (final m in RegExp(r'class\s+(\w+)\s+extends\s+([\w<>]+)').allMatches(src)) {
    if (m.start > offset) break;
    final base = m.group(2)!;
    final st = RegExp(r'^State<(\w+)>').firstMatch(base);
    name = st != null ? st.group(1)! : m.group(1)!;
  }
  return name;
}

// Match the bracket at [open] ('(' or '['), honoring strings + comments.
int _matchBracket(String s, int open) {
  final openCh = s[open];
  final closeCh = openCh == '[' ? ']' : ')';
  var depth = 0;
  var i = open;
  while (i < s.length) {
    final c = s[i];
    if (c == "'" || c == '"') { i = _skipString(s, i); continue; }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      while (i < s.length && s[i] != '\n') i++;
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < s.length && !(s[i] == '*' && s[i + 1] == '/')) i++;
      i += 2;
      continue;
    }
    if (c == openCh) depth++;
    else if (c == closeCh) { depth--; if (depth == 0) return i; }
    i++;
  }
  return -1;
}

int _skipString(String s, int i) {
  final q = s[i];
  i++;
  while (i < s.length) {
    if (s[i] == r'\') { i += 2; continue; }
    if (s[i] == q) return i + 1;
    i++;
  }
  return i;
}

String _slug(String className) {
  var s = className.replaceAll(RegExp(r'(Screen|Page|View|Widget)$'), '');
  s = s.replaceAll(RegExp(r'^_+'), '');
  s = s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  s = s.replaceFirst(RegExp(r'^_'), '');
  return s.isEmpty ? 'screen' : s;
}

String _pkgName() {
  try {
    final pub = File('pubspec.yaml').readAsStringSync();
    return RegExp(r'^name:\s*(\w+)', multiLine: true).firstMatch(pub)?.group(1) ?? 'app';
  } catch (_) {
    return 'app';
  }
}

String _ensureImports(String src) {
  if (!src.contains('package:live_ui_bridge/live_ui_bridge.dart')) {
    src = _addImport(src, "import 'package:live_ui_bridge/live_ui_bridge.dart';");
  }
  if (!src.contains('altera_config.dart')) {
    src = _addImport(src, "import 'package:${_pkgName()}/altera_config.dart';");
  }
  return src;
}

String _addImport(String src, String line) {
  final imports = RegExp(r'^import .*;', multiLine: true).allMatches(src).toList();
  if (imports.isEmpty) return '$line\n$src';
  final at = imports.last.end;
  return '${src.substring(0, at)}\n$line${src.substring(at)}';
}

void _writeConfig(String key, String url) {
  final f = File('lib/altera_config.dart');
  if (f.existsSync()) {
    _p('${_dim}• lib/altera_config.dart already exists — leaving it.$_reset');
    return;
  }
  final keyVal = key.isEmpty ? 'ak_REPLACE_ME' : key;
  f.writeAsStringSync('''
// Generated by `dart run live_ui_bridge:wrap`. One place for your ALTERA setup —
// every wrapped screen references `alteraConfig`.
import 'package:live_ui_bridge/live_ui_bridge.dart';

const alteraConfig = BridgeConfig(
  url: '$url',
  appId: 'app',
  token: 'app-secret-dev',
  // Or pass at run time: --dart-define=ALTERA_API_KEY=ak_…
  apiKey: String.fromEnvironment('ALTERA_API_KEY', defaultValue: '$keyVal'),
  environment: 'draft',
);

// ONE shared connection for the whole app → a single device in the dashboard
// (every wrapped screen + the AlteraMirror reuse it).
final alteraClient = BridgeClient(alteraConfig)..connect();
''');
  _p('$_green✓ Wrote lib/altera_config.dart$_reset');
  _p('');
}
