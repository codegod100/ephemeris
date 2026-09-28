import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:helios_sky/astro/astro_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helios_sky/sensors/orientation_service.dart';
import 'package:helios_sky/state/sky_model.dart';
import 'package:helios_sky/ui/ar_camera.dart';
import 'package:helios_sky/ui/sky_painter.dart';

void main() {
  testWidgets('sky painter renders day and night views without errors', (tester) async {
    for (final ar in [false, true]) {
      for (final t in [DateTime.utc(2026, 6, 21, 19), DateTime.utc(2026, 12, 21, 5)]) {
        for (final (az, alt) in [(180.0, 30.0), (0.0, 0.0), (90.0, 89.0), (270.0, -45.0)]) {
          await tester.pumpWidget(MaterialApp(
            home: CustomPaint(
              size: const Size(400, 800),
              painter: SkyPainter(
                sky: SkySnapshot.compute(t, 40.0, -74.0),
                cam: CameraBasis.fromAzAlt(az, alt),
                fov: 90,
                showStars: true,
                showConstellations: true,
                showPlanets: true,
                showGrid: true,
              showEcliptic: true,
              showVedic: true,
                showSunPath: true,
                showLabels: true,
                showAtmosphere: true,
                selected: 'Sun',
                ar: ar,
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  test('AR screen FOV follows the camera lens and crop', () {
    // Preview exactly the screen's shape: the long side shows the full lens FOV.
    const lens = 66.0;
    final fullFrame = arScreenFov(const Size(300, 400), const Size(3, 4), lens);
    expect(fullFrame, closeTo(2 * math.atan(0.75 * math.tan(lens / 2 * math.pi / 180)) * 180 / math.pi, 1e-9));
    // A tall phone screen crops the sides of a 4:3 preview, narrowing the view.
    final tall = arScreenFov(const Size(390, 844), const Size(3, 4), lens);
    expect(tall, lessThan(fullFrame));
    expect(tall, closeTo(2 * math.atan(390 / 844 * math.tan(lens / 2 * math.pi / 180)) * 180 / math.pi, 1e-9));
  });

  test('rectilinear projection maps the edge of the FOV to the screen edge', () {
    final cam = CameraBasis.fromAzAlt(180, 0);
    final proj = SkyProjection(cam, const Size(400, 800), 60, rectilinear: true);
    final edge = proj.project(Horizontal(180 + 30, 0).toEnu())!;
    expect(edge.dx, anyOf(closeTo(0, 1e-6), closeTo(400, 1e-6)));
    expect(proj.project(Horizontal(0, 0).toEnu()), isNull); // behind the camera
  });
}
