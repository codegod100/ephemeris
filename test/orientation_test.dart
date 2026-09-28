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

  test('heading offset rotates azimuth', () {
    final b = CameraBasis.fromAzAlt(100, 10).rotatedAboutUp(12.5);
    expect(b.azimuth, closeTo(112.5, 1e-6));
    expect(b.altitude, closeTo(10, 1e-6));
  });
}
