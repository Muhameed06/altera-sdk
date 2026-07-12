import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bridge_client.dart';

/// Wrap your app's root once so the dashboard can mirror the live screen — no
/// adb, works on cloud and any device. Streams a PNG of the app over the SAME
/// shared [client] used by your wrapped screens (so it's one connection, one
/// device in the dashboard). Only streams while a dashboard editor is watching.
///
/// ```dart
/// runApp(AlteraMirror(client: alteraClient, child: MyApp()));
/// ```
class AlteraMirror extends StatefulWidget {
  const AlteraMirror({required this.child, required this.client, this.fps = 2, super.key});

  final Widget child;
  final BridgeClient client;
  final int fps;

  @override
  State<AlteraMirror> createState() => _AlteraMirrorState();
}

class _AlteraMirrorState extends State<AlteraMirror> {
  final GlobalKey _key = GlobalKey();
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ms = (1000 / widget.fps).round().clamp(200, 2000);
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const double _pr = 0.85; // capture pixel ratio (kept small for the wire)

  Future<void> _send() async {
    if (_busy) return;
    if (!widget.client.editorPresent.value) return; // only when the dashboard is open
    final ro = _key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || ro.debugNeedsPaint || !ro.hasSize) return;
    _busy = true;
    try {
      final image = await ro.toImage(pixelRatio: _pr);
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      widget.client.reportAppFrame({
        'screen': 'app',
        'png': base64Encode(bytes.buffer.asUint8List()),
        'w': ro.size.width,
        'h': ro.size.height,
        'pr': _pr, // logical→image scale, so the dashboard overlay lines up
      });
    } catch (_) {
      // transient (mid-frame / detached) — next tick retries
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _key, child: widget.child);
}
