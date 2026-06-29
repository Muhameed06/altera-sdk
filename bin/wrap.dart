// ignore_for_file: unnecessary_brace_in_string_interps
// ALTERA wrap tool — `dart run live_ui_bridge:wrap`
//
// Scans your Flutter app's lib/, finds every screen (a widget whose build
// returns a Scaffold), and makes them editable from the ALTERA dashboard:
//   • generates a shared lib/altera_config.dart (one place for your apiKey)
//   • reports every screen + the exact one-line wrap for it
//   • with --apply: auto-wraps the clean cases (and backs up each file as .bak)
//
// Usage:
//   dart run live_ui_bridge:wrap                 # scan + report (no changes)
//   dart run live_ui_bridge:wrap --apply         # also auto-wrap clean screens
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

class Screen {
  Screen(this.file, this.className, this.id, this.canAutoWrap);
  final String file;
  final String className;
  final String id;
  final bool canAutoWrap;
}

void main(List<String> args) {
  final apply = args.contains('--apply');
  final keyArg = args.firstWhere((a) => a.startsWith('--key='), orElse: () => '');
  final key = keyArg.isEmpty ? '' : keyArg.substring('--key='.length);

  _p('');
  _p('$_bold${_magenta}▲ ALTERA — wrap your pages$_reset');
  _p('${_dim}Make every screen editable from the dashboard.$_reset');
  _p('');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    _p('$_yellow✗ No lib/ directory here. Run this from your Flutter app root.$_reset');
    exit(1);
  }

  // 1) Shared config file.
  _writeConfig(key);

  // 2) Scan for screens.
  final screens = <Screen>[];
  for (final f in libDir.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart') || f.path.contains('/gen/')) continue;
    if (f.path.endsWith('altera_config.dart')) continue;
    final src = f.readAsStringSync();
    if (!src.contains('Scaffold(')) continue;

    final m = RegExp(r'class\s+(\w+)\s+extends\s+(StatelessWidget|StatefulWidget)').firstMatch(src);
    if (m == null) continue;
    final className = m.group(1)!;
    final id = _slug(className);
    // Clean auto-wrap target: a Column/ListView whose first arg is `children:`.
    final canAuto = RegExp(r'(Column|ListView)\(\s*children:\s*\[').hasMatch(src);
    screens.add(Screen(f.path, className, id, canAuto));
  }

  if (screens.isEmpty) {
    _p('${_yellow}No screens found (no widget classes returning a Scaffold).$_reset');
    _p('${_dim}Tip: wrap any list of widgets directly with RemoteUI.auto(...).$_reset');
    return;
  }

  _p('${_bold}Found ${screens.length} screen${screens.length == 1 ? '' : 's'}:$_reset');
  _p('');
  for (final s in screens) {
    final tag = s.canAutoWrap ? '$_green● auto$_reset' : '$_yellow○ manual$_reset';
    _p('  $tag  $_bold${s.className}$_reset  $_dim(${s.file})$_reset');
  }
  _p('');

  // 3) Apply or report.
  var wrapped = 0;
  final manual = <Screen>[];
  for (final s in screens) {
    if (apply && s.canAutoWrap) {
      if (_autoWrap(s)) {
        wrapped++;
      } else {
        manual.add(s);
      }
    } else {
      manual.add(s);
    }
  }

  if (apply) {
    _p('$_green✓ Auto-wrapped $wrapped screen${wrapped == 1 ? '' : 's'}$_reset ${_dim}(originals saved as *.bak)$_reset');
    _p('');
  }

  if (manual.isNotEmpty) {
    _p('${_bold}${apply ? 'Wrap these by hand' : 'How to wrap each'}:$_reset ${_dim}one line per screen$_reset');
    _p('');
    final ex = manual.first;
    _p('${_cyan}  1. import the SDK + your config at the top of the file:$_reset');
    _p("       import 'package:live_ui_bridge/live_ui_bridge.dart';");
    _p("       import 'package:${_pkgName()}/altera_config.dart';");
    _p('');
    _p('${_cyan}  2. wrap your screen body\'s children list:$_reset');
    _p('${_dim}       // before:$_reset  Column(children: [sectionA, sectionB])');
    _p('${_green}       // after: $_reset  RemoteUI.auto(');
    _p("                   screen: '${ex.id}', editable: true, blocksOnly: true,");
    _p('                   config: alteraConfig, children: [sectionA, sectionB])');
    _p('');
  }

  _p('${_bold}Then run your app:$_reset  flutter run ${_dim}(pass --dart-define=ALTERA_API_KEY=ak_… if you didn\'t bake the key in)$_reset');
  _p('${_dim}Open https://altera-82d02.web.app, pick a page, drag to reorder — live on the device.$_reset');
  _p('');
}

String _slug(String className) {
  var s = className.replaceAll(RegExp(r'(Screen|Page|View|Widget)$'), '');
  s = s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  s = s.replaceFirst(RegExp(r'^_'), '');
  return s.isEmpty ? 'screen' : s;
}

String _pkgName() {
  try {
    final pub = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^name:\s*(\w+)', multiLine: true).firstMatch(pub);
    return m?.group(1) ?? 'app';
  } catch (_) {
    return 'app';
  }
}

void _writeConfig(String key) {
  final f = File('lib/altera_config.dart');
  if (f.existsSync()) {
    _p('${_dim}• lib/altera_config.dart already exists — leaving it.$_reset');
    return;
  }
  final keyLine = key.isEmpty
      ? "  // Paste your key from the dashboard → Setup, or pass --dart-define=ALTERA_API_KEY=ak_…\n  apiKey: const String.fromEnvironment('ALTERA_API_KEY', defaultValue: 'ak_REPLACE_ME'),"
      : "  apiKey: const String.fromEnvironment('ALTERA_API_KEY', defaultValue: '$key'),";
  f.writeAsStringSync('''
// Generated by `dart run live_ui_bridge:wrap`. One place for your ALTERA setup —
// every wrapped screen references `alteraConfig`.
import 'package:live_ui_bridge/live_ui_bridge.dart';

const alteraConfig = BridgeConfig(
  url: 'wss://altera-backend-1075554014912.europe-west1.run.app',
  appId: 'app',
  token: 'app-secret-dev',
$keyLine
  environment: 'draft',
);
''');
  _p('$_green✓ Wrote lib/altera_config.dart$_reset');
}

// Conservative auto-wrap: turn the first `Column(children: [ … ])` /
// `ListView(children: [ … ])` in a screen into a RemoteUI.auto(...) wrapping the
// SAME children. Only the clean "children-first" shape is touched; everything
// else is reported for manual wrapping. Original saved as <file>.bak.
bool _autoWrap(Screen s) {
  final file = File(s.file);
  var src = file.readAsStringSync();
  if (src.contains('RemoteUI.auto(')) return true; // already wrapped

  final re = RegExp(r'(Column|ListView)\(\s*children:\s*\[');
  final match = re.firstMatch(src);
  if (match == null) return false;

  final wasScrollable = match.group(1) == 'ListView';
  final replacement =
      "RemoteUI.auto(\n          screen: '${s.id}',\n          editable: true,\n          blocksOnly: true,\n          scrollable: $wasScrollable,\n          config: alteraConfig,\n          children: [";
  src = src.replaceRange(match.start, match.end, replacement);

  // Ensure imports.
  if (!src.contains("package:live_ui_bridge/live_ui_bridge.dart")) {
    src = _addImport(src, "import 'package:live_ui_bridge/live_ui_bridge.dart';");
  }
  if (!src.contains('altera_config.dart')) {
    src = _addImport(src, "import 'package:${_pkgName()}/altera_config.dart';");
  }

  file.copySync('${s.file}.bak');
  file.writeAsStringSync(src);
  return true;
}

String _addImport(String src, String line) {
  final lastImport = RegExp(r'^import .*;', multiLine: true).allMatches(src).toList();
  if (lastImport.isEmpty) return '$line\n$src';
  final at = lastImport.last.end;
  return '${src.substring(0, at)}\n$line${src.substring(at)}';
}
