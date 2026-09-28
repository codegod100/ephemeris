import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../astro/astro_math.dart';
import 'web_orientation.dart';

typedef Vec3 = List<double>;

Vec3 cross(Vec3 a, Vec3 b) => [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
double dot(Vec3 a, Vec3 b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
double norm(Vec3 a) => math.sqrt(dot(a, a));
Vec3 normalize(Vec3 a) {
  final n = norm(a);
  return n == 0 ? [0, 0, 0] : [a[0] / n, a[1] / n, a[2] / n];
}

/// Camera basis expressed in the local East-North-Up frame.
///  * [right]   – direction of the screen's +x
///  * [up]      – direction of the screen's top edge
///  * [forward] – direction the back of the phone (camera) points
class CameraBasis {
  final Vec3 right, up, forward;
  const CameraBasis(this.right, this.up, this.forward);

  /// Builds a basis looking at azimuth/altitude with no roll.
  factory CameraBasis.fromAzAlt(double az, double alt) {
    final f = Horizontal(az, alt).toEnu();
    final r = [cosD(az), -sinD(az), 0.0];
    return CameraBasis(r, cross(r, f), f);
  }

  double get azimuth => normDeg(atan2D(forward[0], forward[1]));
  double get altitude => asinD(forward[2]);

  /// Rotates the whole basis about the Up axis by [deg] (adds to azimuth).
  CameraBasis rotatedAboutUp(double deg) {
    if (deg == 0) return this;
    final c = cosD(deg), s = sinD(deg);
    Vec3 rot(Vec3 v) => [v[0] * c + v[1] * s, -v[0] * s + v[1] * c, v[2]];
    return CameraBasis(rot(right), rot(up), rot(forward));
  }
}

/// Fuses accelerometer + magnetometer into a device orientation, like
/// Android's SensorManager.getRotationMatrix, with exponential smoothing.
///
/// Browsers don't expose the magnetometer, so on the web the orientation
/// comes from the browser's own compass-referenced orientation events.
class OrientationService extends ChangeNotifier {
  OrientationService({this.smoothing = 0.12});

  /// Low-pass factor (0..1). Lower = smoother but laggier.
  double smoothing;

  Vec3? _gravity;
  Vec3? _magnetic;
  CameraBasis? _basis;
  bool _available = true;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<void>? _webSub;
  bool _needsPermission = false;

  CameraBasis? get basis => _basis;
  bool get available => _available;
  bool get running => _accSub != null || _webSub != null;

  /// True on iOS Safari until the user grants motion access from a tap.
  bool get needsPermission => _needsPermission;

  /// Must be called from a user gesture (a button tap).
  Future<void> requestPermission() async {
    final granted = await requestWebOrientationPermission();
    _needsPermission = false;
    if (granted) {
      _startWeb();
    } else {
      _markUnavailable();
    }
    notifyListeners();
  }

  /// True when the magnetic field magnitude looks unlike Earth's
  /// (~25–65 µT), which usually means interference or an uncalibrated compass.
  bool get magneticInterference {
    final m = _magnetic;
    if (m == null) return false;
    final n = norm(m);
    return n < 15 || n > 90;
  }

  void start() {
    if (running) return;
    if (kIsWeb) {
      if (!webOrientationSupported) {
        _markUnavailable();
      } else if (webOrientationNeedsPermission) {
        _needsPermission = true;
        notifyListeners();
      } else {
        _startWeb();
      }
      return;
    }
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        _gravity = _lowPass(_gravity, [e.x, e.y, e.z]);
        _recompute();
      },
      onError: (_) => _markUnavailable(),
      cancelOnError: true,
    );
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        _magnetic = _lowPass(_magnetic, [e.x, e.y, e.z]);
        _recompute();
      },
      onError: (_) => _markUnavailable(),
      cancelOnError: true,
    );
  }

  void stop() {
    _accSub?.cancel();
    _magSub?.cancel();
    _webSub?.cancel();
    _accSub = null;
    _magSub = null;
    _webSub = null;
  }

  void _startWeb() {
    _webSub = listenWebOrientation((alpha, beta, gamma) {
      final b = basisFromEuler(alpha, beta, gamma);
      final prev = _basis;
      // Smooth the pointing and up directions, then re-orthonormalise.
      final f = prev == null ? b.forward : normalize(_lowPass(prev.forward, b.forward));
      final u0 = prev == null ? b.up : _lowPass(prev.up, b.up);
      final r = normalize(cross(f, u0));
      _basis = CameraBasis(r, cross(r, f), f);
      notifyListeners();
    });
  }

  void _markUnavailable() {
    _available = false;
    stop();
    notifyListeners();
  }

  Vec3 _lowPass(Vec3? prev, Vec3 next) {
    if (prev == null) return next;
    final a = smoothing;
    return [
      prev[0] + a * (next[0] - prev[0]),
      prev[1] + a * (next[1] - prev[1]),
      prev[2] + a * (next[2] - prev[2]),
    ];
  }

  void _recompute() {
    final g = _gravity, m = _magnetic;
    if (g == null || m == null) return;
    final b = basisFromSensors(g, m);
    if (b == null) return;
    _basis = b;
    notifyListeners();
  }

  /// Pure function so it can be unit tested.
  ///
  /// Device axes (Android convention, also used by sensors_plus on iOS):
  /// +x to the right of the screen, +y to the top, +z out of the screen.
  static CameraBasis? basisFromSensors(Vec3 gravity, Vec3 magnetic) {
    final a = gravity;
    var h = cross(magnetic, a);
    final hn = norm(h);
    if (hn < 0.1 || norm(a) < 0.1) return null; // free fall or near magnetic pole
    h = [h[0] / hn, h[1] / hn, h[2] / hn];
    final an = normalize(a);
    final mm = cross(an, h);
    // Rows of R are world East (h), North (mm), Up (an) in device coordinates.
    // A device vector d maps to world as (h·d, mm·d, an·d).
    final right = [h[0], mm[0], an[0]];
    final up = [h[1], mm[1], an[1]];
    final forward = [-h[2], -mm[2], -an[2]];
    return CameraBasis(right, up, forward);
  }

  /// Camera basis from W3C DeviceOrientation Euler angles (degrees), where
  /// the rotation R = Rz(alpha)·Rx(beta)·Ry(gamma) takes device coordinates
  /// to East-North-Up when alpha is referenced to north. Device axes match
  /// [basisFromSensors].
  static CameraBasis basisFromEuler(double alpha, double beta, double gamma) {
    final ca = cosD(alpha), sa = sinD(alpha);
    final cb = cosD(beta), sb = sinD(beta);
    final cg = cosD(gamma), sg = sinD(gamma);
    // Columns of R: images of device x, y and z.
    final x = [ca * cg - sa * sb * sg, sa * cg + ca * sb * sg, -cb * sg];
    final y = [-sa * cb, ca * cb, sb];
    final z = [ca * sg + sa * sb * cg, sa * sg - ca * sb * cg, cb * cg];
    return CameraBasis(x, y, [-z[0], -z[1], -z[2]]);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
