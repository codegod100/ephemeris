import 'dart:async';

bool get webOrientationSupported => false;

bool get webOrientationNeedsPermission => false;

Future<bool> requestWebOrientationPermission() async => false;

/// Calls [onData] with absolute (north-referenced) W3C Euler angles in degrees.
StreamSubscription<void>? listenWebOrientation(void Function(double alpha, double beta, double gamma) onData) => null;
