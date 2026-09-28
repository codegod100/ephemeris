import 'dart:ui' show Color;

import '../astro/astro_math.dart';
import '../astro/moon.dart';
import '../astro/planets.dart';
import '../astro/stars.dart';
import '../astro/sun.dart';

enum SkyObjectKind { sun, moon, planet, star }

class SkyObject {
  final String name;
  final SkyObjectKind kind;
  final Horizontal pos;
  final double mag;
  final Color color;
  final List<double> enu;
  SkyObject(this.name, this.kind, this.pos, this.mag, this.color) : enu = pos.toEnu();
}

class SunPathPoint {
  final DateTime time;
  final Horizontal pos;
  final List<double> enu;
  SunPathPoint(this.time, this.pos) : enu = pos.toEnu();
}

/// Everything the sky view needs for one instant, computed once per tick
/// (not once per frame) so rendering stays cheap.
class SkySnapshot {
  final DateTime time;
  final double lat, lon;
  final SkyObject sun;
  final SkyObject moon;
  final double moonFraction;
  final double moonAge;
  final List<SkyObject> planets;
  final List<SkyObject> stars;
  final Map<String, SkyObject> starsByName;
  final List<SunPathPoint> sunPath;

  SkySnapshot._(this.time, this.lat, this.lon, this.sun, this.moon, this.moonFraction, this.moonAge,
      this.planets, this.stars, this.sunPath)
      : starsByName = {for (final s in stars) s.name: s};

  factory SkySnapshot.compute(DateTime t, double lat, double lon) {
    final tc = centuriesTT(t);
    final sun = SkyObject('Sun', SkyObjectKind.sun, sunHorizontal(t, lat, lon), -26.7,
        const Color(0xFFFFD54F));
    final moon = SkyObject('Moon', SkyObjectKind.moon, moonHorizontal(t, lat, lon), -12,
        const Color(0xFFECEFF1));
    final phase = moonPhase(t);
    final planets = [
      for (final p in Planet.values)
        SkyObject(p.label, SkyObjectKind.planet, planetHorizontal(p, t, lat, lon), p.typicalMag,
            Color(p.argb)),
    ];
    final stars = [
      for (final s in brightStars)
        SkyObject(
          s.name,
          SkyObjectKind.star,
          equatorialToHorizontal(precessFromJ2000(Equatorial(s.ra, s.dec), tc), t, lat, lon),
          s.mag,
          const Color(0xFFFFFFFF),
        ),
    ];
    final day = DateTime(t.year, t.month, t.day);
    final path = [
      for (var m = 0; m <= 24 * 60; m += 10)
        SunPathPoint(day.add(Duration(minutes: m)),
            sunHorizontal(day.add(Duration(minutes: m)), lat, lon)),
    ];
    return SkySnapshot._(t, lat, lon, sun, moon, phase.fraction, phase.ageDegrees, planets, stars, path);
  }

  Iterable<SkyObject> get allObjects sync* {
    yield sun;
    yield moon;
    yield* planets;
    yield* stars;
  }
}
