import 'dart:ui' show Color;

import '../astro/astro_math.dart';
import '../astro/moon.dart';
import '../astro/planets.dart';
import '../astro/stars.dart';
import '../astro/sun.dart';
import '../astro/vedic.dart';

enum SkyObjectKind { sun, moon, planet, star, node }

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

/// Lines and markers for the ecliptic, celestial equator and the sidereal
/// zodiac, as ENU unit vectors for one instant.
class ZodiacGeometry {
  final List<List<double>> ecliptic;
  final List<List<double>> equator;

  /// Equinoxes and solstices (tropical 0°, 90°, 180°, 270°).
  final List<(String, List<double>)> seasonPoints;

  /// Rashi / nakshatra boundaries as short segments across the ecliptic.
  final List<(List<double>, List<double>)> rashiTicks, nakshatraTicks;
  final List<(String, List<double>)> rashiLabels, nakshatraLabels;

  /// When the Sun enters each nakshatra (nearest occurrence), index-aligned with [nakshatraLabels].
  final List<DateTime> nakshatraEntries;

  /// When the Moon next enters each nakshatra, index-aligned with [nakshatraLabels].
  final List<DateTime> nakshatraMoonEntries;

  ZodiacGeometry._(this.ecliptic, this.equator, this.seasonPoints, this.rashiTicks, this.nakshatraTicks,
      this.rashiLabels, this.nakshatraLabels, this.nakshatraEntries, this.nakshatraMoonEntries);

  factory ZodiacGeometry.compute(DateTime t, double lat, double lon) {
    final tc = centuriesTT(t);
    final eps = meanObliquity(tc);
    final ayan = lahiriAyanamsa(tc);
    List<double> ecl(double tropicalLon, [double eclLat = 0]) =>
        equatorialToHorizontal(eclipticToEquatorial(tropicalLon, eclLat, eps), t, lat, lon).toEnu();
    List<double> sid(double siderealLon, [double eclLat = 0]) => ecl(siderealLon + ayan, eclLat);
    return ZodiacGeometry._(
      [for (var l = 0; l <= 360; l += 2) ecl(l.toDouble())],
      [for (var ra = 0; ra <= 360; ra += 2) equatorialToHorizontal(Equatorial(ra.toDouble(), 0), t, lat, lon).toEnu()],
      [
        ('♈ March equinox', ecl(0)),
        ('June solstice', ecl(90)),
        ('♎ September equinox', ecl(180)),
        ('December solstice', ecl(270)),
      ],
      [for (var i = 0; i < 12; i++) (sid(i * 30.0, -9), sid(i * 30.0, 9))],
      [for (var i = 0; i < 27; i++) (sid(i * nakshatraSpan, -3), sid(i * nakshatraSpan, 3))],
      [for (var i = 0; i < 12; i++) (rashis[i].name, sid(i * 30.0 + 15, 6))],
      [for (var i = 0; i < 27; i++) (nakshatras[i], sid((i + 0.5) * nakshatraSpan, -4.5))],
      [for (var i = 0; i < 27; i++) sunEntersNakshatra(t, i)],
      [for (var i = 0; i < 27; i++) moonEntersNakshatra(t, i)],
    );
  }
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

  /// Rahu and Ketu, the lunar nodes (points on the ecliptic, not bodies).
  final List<SkyObject> nodes;
  final List<GrahaPosition> grahas;
  final double ayanamsa;
  final ZodiacGeometry zodiac;

  /// Nakshatra index the Moon will be in at the next new / full Moon.
  final int newMoonNakshatra, fullMoonNakshatra;

  SkySnapshot._(this.time, this.lat, this.lon, this.sun, this.moon, this.moonFraction, this.moonAge,
      this.planets, this.stars, this.sunPath, this.nodes, this.grahas, this.ayanamsa, this.zodiac, this.newMoonNakshatra, this.fullMoonNakshatra)
      : starsByName = {for (final s in stars) s.name: s};

  /// The graha shown by a sky object (Sun, Moon, Mars … Rahu, Ketu), if any.
  GrahaPosition? grahaFor(SkyObject o) {
    for (final g in grahas) {
      if (g.graha.english == o.name || g.graha.sanskrit == o.name) return g;
    }
    return null;
  }

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
    final eps = meanObliquity(tc);
    final rahuLon = meanLunarNode(tc);
    SkyObject node(String name, double eclLon) => SkyObject(name, SkyObjectKind.node,
        equatorialToHorizontal(eclipticToEquatorial(eclLon, 0, eps), t, lat, lon), 0, const Color(0xFFB39DDB));
    final nodes = [node('Rahu', rahuLon), node('Ketu', rahuLon + 180)];
    return SkySnapshot._(t, lat, lon, sun, moon, phase.fraction, phase.ageDegrees, planets, stars, path, nodes,
        grahaPositions(t), lahiriAyanamsa(tc), ZodiacGeometry.compute(t, lat, lon),
        moonNakshatraIndexAt(nextMoonPhaseTime(t, 0)), moonNakshatraIndexAt(nextMoonPhaseTime(t, 180)));
  }

  Iterable<SkyObject> get allObjects sync* {
    yield sun;
    yield moon;
    yield* planets;
    yield* nodes;
    yield* stars;
  }
}
