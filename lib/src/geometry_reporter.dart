import 'dart:async';
import 'dart:ui';

/// Collects the on-screen rect of every node (in edit mode) and emits the batch
/// via [sink], debounced so a burst of layout reports coalesces into one.
///
/// Rects are in logical pixels. [dpr] (device pixel ratio) is included so a
/// consumer mapping onto a physical-pixel screenshot (a device mirror) can
/// scale correctly; the web overlay ignores it (logical == CSS px there).
class GeometryReporter {
  GeometryReporter(this.screen, this.sink) {
    // Heartbeat re-emit so a dashboard that connects (or reconnects) after the
    // last layout change still receives current geometry within a couple seconds.
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_rects.isNotEmpty) _emit();
    });
  }

  final String screen;
  final void Function(Map<String, dynamic> payload) sink;
  final Map<String, Rect> _rects = {};
  Timer? _timer;
  Timer? _heartbeat;

  /// Set by the host (from MediaQuery) before each frame.
  double dpr = 1;

  void report(String id, Rect rect) {
    final prev = _rects[id];
    if (prev != null && prev == rect) return;
    _rects[id] = rect;
    _timer ??= Timer(const Duration(milliseconds: 50), _emit);
  }

  void _emit() {
    _timer = null;
    final rects = <String, dynamic>{};
    _rects.forEach((id, r) {
      rects[id] = {'left': r.left, 'top': r.top, 'width': r.width, 'height': r.height};
    });
    sink({'screen': screen, 'rects': rects, 'dpr': dpr});
  }

  void dispose() {
    _timer?.cancel();
    _heartbeat?.cancel();
  }
}
