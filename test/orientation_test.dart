import 'package:flutter_test/flutter_test.dart';
import 'package:helios_sky/sensors/orientation_service.dart';

void main() {
  test('phone upright, back facing north → forward=N, up=Up, right=E', () {
    // Upright portrait: gravity reaction along +y. Northern-hemisphere field
    // points north (device −z) and down (device −y).
    final b = OrientationService.basisFromSensors([0, 9.81, 0], [0, -40, -20])!;
    expect(b.forward[0], closeTo(0, 1e-9));
    expect(b.forward[1], closeTo(1, 1e-9));
    expect(b.up[2], closeTo(1, 1e-9));
    expect(b.right[0], closeTo(1, 1e-9));
    expect(b.azimuth, closeTo(0, 1e-6));
    expect(b.altitude, closeTo(0, 1e-6));
  });

  test('phone upright facing east', () {
    // Back (−z) faces east, so north is along device −x... i.e. +x points south.
    final b = OrientationService.basisFromSensors([0, 9.81, 0], [-20, -40, 0])!;
    expect(b.azimuth, closeTo(90, 1e-6));
  });

  test('phone tilted up 30° while facing south', () {
    final basis = CameraBasis.fromAzAlt(180, 30);
    expect(basis.azimuth, closeTo(180, 1e-6));
    expect(basis.altitude, closeTo(30, 1e-6));
  });

  test('web Euler angles: upright facing north', () {
    final b = OrientationService.basisFromEuler(0, 90, 0);
    expect(b.azimuth, closeTo(0, 1e-6));
    expect(b.altitude, closeTo(0, 1e-6));
    expect(b.right[0], closeTo(1, 1e-9));
    expect(b.up[2], closeTo(1, 1e-9));
  });

  test('web Euler angles agree with the accelerometer/magnetometer fusion', () {
    for (final (a, be, g) in [(0.0, 90.0, 0.0), (270.0, 80.0, 5.0), (123.0, 40.0, -30.0), (45.0, 120.0, 20.0)]) {
      final e = OrientationService.basisFromEuler(a, be, g);
      // Columns of R are the device axes in ENU, so a world vector w has
      // device coordinates (w·x, w·y, w·z) where z = −forward.
      final z = [-e.forward[0], -e.forward[1], -e.forward[2]];
      List<double> toDevice(List<double> w) => [dot(w, e.right), dot(w, e.up), dot(w, z)];
      final s = OrientationService.basisFromSensors(toDevice([0, 0, 9.81]), toDevice([0, 30, -40]))!;
      for (var i = 0; i < 3; i++) {
        expect(s.forward[i], closeTo(e.forward[i], 1e-9));
        expect(s.up[i], closeTo(e.up[i], 1e-9));
        expect(s.right[i], closeTo(e.right[i], 1e-9));
      }
    }
  });

  test('heading offset rotates azimuth', () {
    final b = CameraBasis.fromAzAlt(100, 10).rotatedAboutUp(12.5);
    expect(b.azimuth, closeTo(112.5, 1e-6));
    expect(b.altitude, closeTo(10, 1e-6));
  });
}
