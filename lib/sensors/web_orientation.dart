/// Browser orientation events (web only). On other platforms every call is a
/// no-op and [webOrientationSupported] is false.
library;

export 'web_orientation_stub.dart' if (dart.library.js_interop) 'web_orientation_web.dart';
