import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helios_sky/sensors/orientation_service.dart';
import 'package:helios_sky/state/sky_model.dart';
import 'package:helios_sky/ui/sky_painter.dart';

void main() {
  testWidgets('sky painter renders day and night views without errors', (tester) async {
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
              showSunPath: true,
              showLabels: true,
              showAtmosphere: true,
              selected: 'Sun',
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
