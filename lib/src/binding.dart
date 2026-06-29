/// Data binding + condition resolution for the layout graph.
///
/// - `interpolate('Hi {{user.name}}', data)` → `'Hi Sam'`
/// - `evalCondition('cart.count > 0', data)` → bool
///
/// Bindings resolve against the synced data context (a plain JSON map). The
/// evaluator is intentionally tiny and safe (no `eval`): a single comparison or
/// a truthy/negated path.
class Binding {
  static final RegExp _tpl = RegExp(r'\{\{\s*([\w.]+)\s*\}\}');
  static final RegExp _cond = RegExp(r'^\s*(!?)\s*([\w.]+)\s*(==|!=|>=|<=|>|<)?\s*(.*?)\s*$');

  /// Replace every `{{ path }}` with the resolved value (missing → empty).
  static String interpolate(String s, Map<String, dynamic> data) {
    if (!s.contains('{{')) return s;
    return s.replaceAllMapped(_tpl, (m) {
      final v = resolve(m.group(1)!, data);
      return v == null ? '' : '$v';
    });
  }

  /// True when [s] contains at least one `{{ }}` binding.
  static bool hasBinding(String s) => s.contains('{{');

  /// Walk a dotted path (`a.b.c`) through nested maps. Returns null if missing.
  static dynamic resolve(String path, Map<String, dynamic> data) {
    dynamic cur = data;
    for (final key in path.split('.')) {
      if (cur is Map && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// Evaluate a visibility condition. Empty/blank → true (always visible).
  static bool evalCondition(String? expr, Map<String, dynamic> data) {
    if (expr == null) return true;
    final e = expr.trim();
    if (e.isEmpty) return true;
    final m = _cond.firstMatch(e);
    if (m == null) return true; // unparseable → don't hide
    final neg = m.group(1) == '!';
    final left = resolve(m.group(2)!, data);
    final op = m.group(3);
    final rhs = (m.group(4) ?? '').trim();

    bool res;
    if (op == null || rhs.isEmpty) {
      res = _truthy(left);
    } else {
      final right = _literal(rhs, data);
      switch (op) {
        case '==':
          res = _eq(left, right);
          break;
        case '!=':
          res = !_eq(left, right);
          break;
        default:
          final l = _asNum(left);
          final r = _asNum(right);
          if (l == null || r == null) {
            res = false;
          } else {
            res = op == '>'
                ? l > r
                : op == '>='
                    ? l >= r
                    : op == '<'
                        ? l < r
                        : l <= r;
          }
      }
    }
    return neg ? !res : res;
  }

  static bool _truthy(dynamic v) {
    if (v == null || v == false || v == 0 || v == '') return false;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return true;
  }

  static num? _asNum(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);

  static bool _eq(dynamic a, dynamic b) {
    final na = _asNum(a);
    final nb = _asNum(b);
    if (na != null && nb != null) return na == nb;
    return '$a' == '$b';
  }

  // A right-hand literal: number, bool, null, 'quoted', or a bareword that is
  // first tried as a data path then falls back to the raw string.
  static dynamic _literal(String raw, Map<String, dynamic> data) {
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    if (raw == 'null') return null;
    final n = num.tryParse(raw);
    if (n != null) return n;
    if (raw.length >= 2 &&
        ((raw.startsWith("'") && raw.endsWith("'")) || (raw.startsWith('"') && raw.endsWith('"')))) {
      return raw.substring(1, raw.length - 1);
    }
    final resolved = resolve(raw, data);
    return resolved ?? raw;
  }
}
