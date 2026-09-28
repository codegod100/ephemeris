import 'package:flutter_test/flutter_test.dart';
import 'package:helios_sky/astro/astro_math.dart';
import 'package:helios_sky/astro/events.dart';
import 'package:helios_sky/astro/moon.dart';
import 'package:helios_sky/astro/planets.dart';
import 'package:helios_sky/astro/stars.dart';
import 'package:helios_sky/astro/sun.dart';

/// Converts a Terrestrial Time instant into the UT DateTime our API expects.
DateTime fromTT(int y, int m, int d, [double hours = 0]) {
  final tt = DateTime.utc(y, m, d).add(Duration(milliseconds: (hours * 3600000).round()));
  final dt = deltaTSeconds(y + (m - 0.5) / 12);
  return tt.subtract(Duration(milliseconds: (dt * 1000).round()));
}

double angDiff(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('time', () {
    test('Julian day of J2000.0', () {
      expect(julianDay(DateTime.utc(2000, 1, 1, 12)), closeTo(2451545.0, 1e-9));
    });

    test('GMST (Meeus example 12.a)', () {
      // 1987 April 10, 0h UT → 13h10m46.3668s
      expect(gmstDeg(DateTime.utc(1987, 4, 10)), closeTo(hmsToDeg(13, 10, 46.3668), 1e-4));
    });
  });

  group('sun', () {
    test('apparent position (Meeus example 25.a)', () {
      final eq = sunEquatorial(fromTT(1992, 10, 13));
      expect(angDiff(eq.ra, hmsToDeg(13, 13, 31.4)), lessThan(0.01));
      expect(eq.dec, closeTo(dmsToDeg(-1, 7, 47, 6), 0.01));
      expect(eq.distanceAu, closeTo(0.99766, 1e-4));
    });

    test('solar noon and equinox day length at (0°, 0°)', () {
      final ev = computeSunEvents(DateTime(2024, 3, 20), 0, 0);
      final noonUtc = ev.solarNoon.toUtc();
      // Equation of time is ≈ −7.5 min on the March equinox.
      final minutes = noonUtc.hour * 60 + noonUtc.minute + noonUtc.second / 60;
      expect(minutes, closeTo(12 * 60 + 7.5, 1.0));
      expect(ev.dayLength!.inMinutes, closeTo(12 * 60 + 7, 3));
    }, skip: DateTime(2024, 3, 20).timeZoneOffset != Duration.zero ? 'needs UTC test TZ' : null);

    test('midnight sun at 80°N on the June solstice', () {
      final ev = computeSunEvents(DateTime(2025, 6, 21), 80, 15);
      expect(ev.sunrise, isNull);
      expect(ev.sunset, isNull);
      expect(ev.noonAltitude, greaterThan(30));
    });

    test('noon altitude equals 90 − |lat − dec|', () {
      final ev = computeSunEvents(DateTime(2025, 6, 21), 40, -3.7);
      final dec = sunEquatorial(ev.solarNoon).dec;
      final expected = 90 - (40 - dec).abs();
      expect(ev.noonAltitude, closeTo(expected + refractionDeg(expected), 0.05));
    });
  });

  group('moon', () {
    test('geocentric position (Meeus example 47.a)', () {
      final mp = moonPosition(fromTT(1992, 4, 12));
      expect(mp.lon, closeTo(133.167265, 0.01)); // apparent λ incl. nutation
      expect(mp.lat, closeTo(-3.229126, 0.01));
      expect(mp.distanceKm, closeTo(368409.7, 50));
      expect(angDiff(mp.equatorial.ra, 134.688470), lessThan(0.02));
      expect(mp.equatorial.dec, closeTo(13.768368, 0.02));
    });

    test('phase is full near 2024-04-23 23:49 UTC', () {
      final ph = moonPhase(DateTime.utc(2024, 4, 23, 23, 49));
      expect(ph.fraction, greaterThan(0.99));
      expect(moonPhaseName(ph.ageDegrees), 'Full Moon');
    });
  });

  group('planets', () {
    test('Venus (Meeus example 33.a) within a few arcminutes', () {
      final eq = planetEquatorial(Planet.venus, fromTT(1992, 12, 20));
      expect(angDiff(eq.ra, hmsToDeg(21, 4, 41.454)), lessThan(0.1));
      expect(eq.dec, closeTo(dmsToDeg(-1, 18, 53, 16.84), 0.1));
      expect(eq.distanceAu, closeTo(0.910947, 0.002));
    });
  });

  group('coordinates', () {
    test('Polaris sits at altitude ≈ latitude', () {
      final t = DateTime.utc(2026, 1, 1);
      final p = starsByName['Polaris']!;
      final eq = precessFromJ2000(Equatorial(p.ra, p.dec), centuriesTT(t));
      final h = equatorialToHorizontal(eq, t, 45, 0, refraction: false);
      expect(h.alt, closeTo(45, 0.8));
      expect(angDiff(h.az, 0), lessThan(1.2));
    });

    test('all constellation lines reference catalog stars', () {
      for (final pair in constellationLines) {
        for (final name in pair) {
          expect(starsByName.containsKey(name), isTrue, reason: name);
        }
      }
    });
  });
}
