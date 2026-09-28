import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

extension type _IosOrientationEvent(JSObject _) implements JSObject {
  /// Safari only: compass heading of the device, clockwise from magnetic north.
  external double? get webkitCompassHeading;
}

JSObject? get _eventClass => globalContext.getProperty<JSObject?>('DeviceOrientationEvent'.toJS);

bool get webOrientationSupported => _eventClass != null;

/// iOS Safari 13+ only delivers orientation events after the page asks, from a
/// user gesture.
bool get webOrientationNeedsPermission => _eventClass?.has('requestPermission') ?? false;

Future<bool> requestWebOrientationPermission() async {
  final cls = _eventClass;
  if (cls == null || !cls.has('requestPermission')) return true;
  try {
    final result = await cls.callMethod<JSPromise<JSString>>('requestPermission'.toJS).toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

/// Calls [onData] with absolute (north-referenced) W3C Euler angles in degrees.
///
/// Chrome on Android fires `deviceorientationabsolute`. Safari fires only a
/// relative `deviceorientation`, but adds `webkitCompassHeading`, from which
/// the offset to north is recovered.
StreamSubscription<void>? listenWebOrientation(void Function(double alpha, double beta, double gamma) onData) {
  if (!webOrientationSupported) return null;
  final window = web.window;
  final hasAbsolute = window.has('ondeviceorientationabsolute');
  final type = hasAbsolute ? 'deviceorientationabsolute' : 'deviceorientation';
  final controller = StreamController<void>();
  double? northOffset;

  void handle(web.Event e) {
    final ev = e as web.DeviceOrientationEvent;
    final alpha = ev.alpha, beta = ev.beta, gamma = ev.gamma;
    if (alpha == null || beta == null || gamma == null) return;
    if (hasAbsolute || ev.absolute) {
      onData(alpha, beta, gamma);
      return;
    }
    final heading = (e as _IosOrientationEvent).webkitCompassHeading;
    if (heading == null || heading < 0) return; // no compass
    // For the W3C frame, heading = 360 − absolute alpha. Smooth the offset
    // on the circle because the compass is noisier than the gyro-fused alpha.
    final target = _wrap(360 - heading - alpha);
    final o = northOffset;
    northOffset = o == null ? target : _wrap(o + 0.05 * _wrap(target - o));
    onData(_wrap(alpha + northOffset!), beta, gamma);
  }

  final listener = handle.toJS;
  window.addEventListener(type, listener);
  controller.onCancel = () => window.removeEventListener(type, listener);
  return controller.stream.listen(null);
}

/// Wraps to −180…180.
double _wrap(double d) => ((d + 180) % 360 + 360) % 360 - 180;
