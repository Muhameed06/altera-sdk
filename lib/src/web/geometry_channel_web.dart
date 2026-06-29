// Web implementation — posts the geometry JSON to the parent frame (the
// dashboard) so it can overlay drop targets on the simulator.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void postGeometry(String json) {
  final parent = html.window.parent;
  if (parent != null && parent != html.window) {
    parent.postMessage(json, '*');
  }
}
