// Posts node geometry to the parent (dashboard) frame. Web-only — the stub is
// used everywhere else, so this is a no-op on mobile/desktop and never runs on
// a real user's device.
export 'geometry_channel_stub.dart' if (dart.library.html) 'geometry_channel_web.dart';
